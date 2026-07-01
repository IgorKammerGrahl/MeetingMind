import 'package:dio/dio.dart';

import 'models/meeting.dart';

class MeetingApi {
  final Dio _dio;
  MeetingApi(this._dio);

  Future<String> uploadMeeting(
    String filePath, {
    String filename = 'recording.m4a',
  }) async {
    final form = FormData.fromMap({
      'audio': await MultipartFile.fromFile(filePath, filename: filename),
    });
    final resp = await _dio.post('/meetings/upload', data: form);
    return (resp.data as Map<String, dynamic>)['id'] as String;
  }

  Future<Meeting> getMeeting(String id) async {
    final resp = await _dio.get('/meetings/$id');
    return Meeting.fromJson(resp.data as Map<String, dynamic>);
  }
}
