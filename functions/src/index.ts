/* eslint-disable */
import * as admin from "firebase-admin";
import { onValueWritten } from "firebase-functions/v2/database";

admin.initializeApp();

/**
 * 승인 상태가 바뀔 때 트리거
 * 경로: /ClubPending/{club}/info/status
 * - "approved" 가 되면 Club/로 승격(이관) + 회장/멤버 등록 + Person/{sid}/club 갱신
 * - "rejected" 는 로그만 남김(필요시 확장)
 */
export const onClubStatusWrite = onValueWritten(
  "/ClubPending/{club}/info/status",
  async (event) => {
    const db = admin.database();
    const clubName = String(event.params.club || "");
    const before = event.data.before.val();
    const after = event.data.after.val();

    // 상태 변화 없으면 무시
    if (before === after) return;

    if (after === "approved") {
      // 대기열의 info 읽기
      const pendingInfoRef = db.ref(`ClubPending/${clubName}/info`);
      const infoSnap = await pendingInfoRef.get();
      if (!infoSnap.exists()) {
        console.log(`[approve] pending info not found: ${clubName}`);
        return;
      }

      const info = infoSnap.val() || {};
      const leaderId = String(info.leaderid ?? info.leaderId ?? "").trim();
      if (!leaderId) {
        console.log(`[approve] leaderId missing for ${clubName}`);
        return;
      }

      // 이미 Club 쪽에 만들어졌다면(재승인 등) 중복 생성 방지
      const clubInfoRef = db.ref(`Club/${clubName}/info`);
      const clubInfoSnap = await clubInfoRef.get();
      if (!clubInfoSnap.exists()) {
        // Club/info로 이관(원 정보 유지, status는 Club엔 저장 안 해도 됨)
        await clubInfoRef.set({
          clubname: info.clubname ?? clubName,
          clubcat: info.clubcat ?? "",
          clubdesc: info.clubdesc ?? "",
          clubimg: info.clubimg ?? "",
          leaderid: leaderId,
          requestedAt: info.requestedAt ?? null,
          requestedByEmail: info.requestedByEmail ?? null,
        });
      }

      // officer: 회장 지정
      await db.ref(`Club/${clubName}/officer/president`).set(leaderId);
      // 멤버에 회장 추가
      await db.ref(`Club/${clubName}/members/${leaderId}`).set(true);

      // Person/{sid}/club 에 중복 없이 추가 (club1, club2... 유지)
      const myClubsRef = db.ref(`Person/${leaderId}/club`);
      const myClubsSnap = await myClubsRef.get();

      let alreadyHas = false;
      if (myClubsSnap.exists()) {
        myClubsSnap.forEach((ch) => {
          if (String(ch.val()) === clubName) alreadyHas = true;
        });
      }
      if (!alreadyHas) {
        const count = myClubsSnap.exists() ? myClubsSnap.numChildren() : 0;
        await myClubsRef.child(`club${count + 1}`).set(clubName);
      }

      // 메타 기록
      await db
        .ref(`Club/${clubName}/approvedAt`)
        .set(admin.database.ServerValue.TIMESTAMP);

      // 원본 pending 노드에 처리 흔적 남기기(선택)
      await db
        .ref(`ClubPending/${clubName}/processedAt`)
        .set(admin.database.ServerValue.TIMESTAMP);

      console.log(`[approve] completed: ${clubName}, leader=${leaderId}`);
      return;
    }

    if (after === "rejected") {
      // 필요시 추가 동작
      console.log(`[reject] club=${clubName}`);
      return;
    }

    console.log(`[status change] ${clubName}: ${before} -> ${after}`);
  }
);
