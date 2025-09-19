import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:gss/homepage.dart';
import 'package:gss/mainpages/csv.dart';

import 'package:gss/mainpages/noticeboard.dart';
import 'package:gss/mainpages/memberlist.dart';
import 'package:gss/mainpages/calendar.dart';
import 'package:gss/mainpages/event.dart';
import 'package:gss/mainpages/group.dart';
import 'package:gss/mainpages/requestlist.dart';
import 'package:gss/mainpages/sync_cal.dart';
import 'package:gss/pages/newclub.dart';
import 'package:gss/services/ApiService.dart';
import 'package:gss/services/AuthService.dart';
import 'package:gss/services/DBservice.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:collection';

import 'package:gss/pages/bungae.dart';

class UserMain extends StatelessWidget {
  const UserMain({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: ClubPage());
  }
}

class ClubPage extends StatefulWidget {
  const ClubPage({super.key});

  @override
  State<ClubPage> createState() => _ClubPageState();
}

class _ClubPageState extends State<ClubPage> {
  Future<List<String>>? _clubFuture;

  @override
  void initState() {
    super.initState();
    _clubFuture = _loadClubs();
  }

  Future<List<String>> _loadClubs() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final userSnap = await FirebaseDatabase.instance
          .ref('Person')
          .orderByChild('email')
          .equalTo(user.email)
          .get();

      if (!userSnap.exists) throw Exception('사용자 정보 없음');

      final userData = (userSnap.value as Map).entries.first;
      final studentId = userData.key;

      final clubSnap =
      await FirebaseDatabase.instance.ref('Person/$studentId/club').get();

      if (!clubSnap.exists) return [];

      final raw = clubSnap.value as Map;
      return raw.values.map((e) => e.toString()).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color.fromRGBO(216, 162, 163, 1.0);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          '내 동아리',
          style: TextStyle(
            fontFamily: "Pretendard",
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => ClubCreatePage()),
              );
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: FutureBuilder<List<String>>(
        future: _clubFuture,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('오류: ${snap.error}'));
          }
          final club = snap.data ?? [];
          if (club.isEmpty) {
            return const Center(child: Text('가입된 동아리가 없습니다.'));
          }


          final width = MediaQuery.of(context).size.width;
          final crossAxisCount = width >= 1000
              ? 4
              : width >= 700
              ? 3
              : 2;

          const spacing = 16.0;
          const horizontalPadding = 16.0;
          const infoHeight = 100.0; // 정보영역 고정 높이

          final availableWidth =
              width - horizontalPadding * 2 - spacing * (crossAxisCount - 1);
          final cardWidth = availableWidth / crossAxisCount;
          final gridMainExtent = cardWidth + infoHeight;

          return GridView.builder(
            padding: const EdgeInsets.all(horizontalPadding),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              mainAxisExtent: gridMainExtent,
            ),
            itemCount: club.length,
            itemBuilder: (_, i) {
              final clubName = club[i];
              return _ClubCard(
                clubName: clubName,
                infoHeight: infoHeight,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => Club(clubName: clubName)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class Club extends StatefulWidget {
  final String clubName;
  const Club({super.key, required this.clubName});

  @override
  State<Club> createState() => _ClubState();
}

class _ClubState extends State<Club> {
  late Future<bool> _canSeeMembers;

  @override
  void initState() {
    super.initState();
    _canSeeMembers = OfficerService.canManage(widget.clubName);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _canSeeMembers,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final showMembers = snap.data ?? false;

        final tabs = <Tab>[
          const Tab(text: '모임'),
          const Tab(text: '정산'),
          const Tab(text: '공지'),
          const Tab(text: '캘린더'),
          if (showMembers) const Tab(text: '부원'),
          if (showMembers) const Tab(text: '가입신청'),
        ];

        final views = <Widget>[
          EventBoard(clubName: widget.clubName),
          LedgerWidget(clubname: widget.clubName),
          NoticeBoard(clubName: widget.clubName),
          CalendarApp(clubName: widget.clubName),
          if (showMembers) MemberList(clubName: widget.clubName),
          if (showMembers) ClubRequestPage(clubName: widget.clubName),
        ];

        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.white,
              title: Text(widget.clubName),
              bottom: TabBar(
                isScrollable: true,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color.fromRGBO(216, 162, 163, 1.0),
                tabs: tabs,
              ),
            ),
            body: TabBarView(children: views),
          ),
        );
      },
    );
  }
}


class _ClubCard extends StatelessWidget {
  final String clubName;
  final VoidCallback onTap;
  final double infoHeight;

  const _ClubCard({
    super.key,
    required this.clubName,
    required this.onTap,
    required this.infoHeight,
  });

  static const accent = Color.fromRGBO(216, 162, 163, 1.0);

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            //이미지
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 2,
                    spreadRadius: 0,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: FutureBuilder<DataSnapshot>(
                    future: FirebaseDatabase.instance
                        .ref("Club/$clubName/info/clubimg")
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.image, color: Colors.grey, size: 48),
                        );
                      }
                      final imageUrl = snapshot.data!.value.toString();
                      return Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        },
                        errorBuilder: (ctx, err, stack) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),

            // 동아리 정보
            SizedBox(
              height: infoHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<String>(
                      future: OfficerService.printingRole(clubName),
                      builder: (context, snapshot) {
                        final roleText =
                        (snapshot.connectionState == ConnectionState.done &&
                            snapshot.hasData)
                            ? snapshot.data!
                            : '';
                        return Text(
                          roleText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: "Pretendard",
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      clubName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: "Pretendard",
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Expanded(
                      child: FutureBuilder<DataSnapshot>(
                        future: FirebaseDatabase.instance
                            .ref("Club/$clubName/info/clubdesc")
                            .get(),
                        builder: (context, s) {
                          final desc = (s.hasData && s.data!.exists)
                              ? s.data!.value.toString()
                              : '동아리 한 줄 소개';
                          return Text(
                            desc,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              height: 1.25,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
