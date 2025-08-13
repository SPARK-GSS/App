import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ApiService extends StatefulWidget {
  const ApiService({super.key});

  @override
  State<ApiService> createState() => _ApiServiceState();
}

class _ApiServiceState extends State<ApiService> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("API TEST"),),
      floatingActionButton: FloatingActionButton(onPressed: fetch),
    );
  }
void fetch() async {
  const baseUrl = "https://openapi.openbanking.or.kr/v2.0/account/transaction_list/fin_num";

  // 필수 파라미터 예시 - 실제 값으로 교체하세요
  const accessToken = "<YOUR_ACCESS_TOKEN>";
  const bankTranId = "F123456789U4BC34239Z";  // 20자리, 은행규칙 준수 필요
  const fintechUseNum = "123456789012345678901234";  // 24자리
  const inquiryType = "A";  // 조회구분코드
  const inquiryBase = "D";  // 조회기준코드
  const fromDate = "20230401";
  const toDate = "20230410";
  const tranDtime = "20230410123000";  // 요청일시 YYYYMMDDhhmmss 형태

  final uri = Uri.parse(baseUrl).replace(queryParameters: {
    "bank_tran_id": bankTranId,
    "fintech_use_num": fintechUseNum,
    "inquiry_type": inquiryType,
    "inquiry_base": inquiryBase,
    "from_date": fromDate,
    "to_date": toDate,
    "tran_dtime": tranDtime,
    // 필요에 따라 추가 파라미터도 넣으세요
  });

  final response = await http.get(
    uri,
    headers: {
      "Authorization": "Bearer $accessToken",
    },
  );

  if (response.statusCode == 200) {
    final json = jsonDecode(response.body);
    print(json);
  } else {
    print("Error: ${response.statusCode}");
    print(response.body);
  }
}


}