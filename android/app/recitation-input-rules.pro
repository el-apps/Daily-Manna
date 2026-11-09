# RecitationAudioInput's fail-closed adapter to record_android 1.4.5.
# Keep the exact private field chain used to find OUR AudioRecord, not another app's capture.
-keep class com.llfbandit.record.RecordPlugin {
    *** callHandler;
}
-keep class com.llfbandit.record.methodcall.MethodCallHandlerImpl {
    *** recorders;
}
-keep class com.llfbandit.record.methodcall.RecorderWrapper {
    *** recorder;
}
-keep class com.llfbandit.record.record.recorder.AudioRecorder {
    *** recorderThread;
    int amPrevAudioMode;
}
-keep class com.llfbandit.record.record.recorder.RecordThread {
    *** mPcmReader;
}
-keep class com.llfbandit.record.record.PCMReader {
    *** reader;
}
