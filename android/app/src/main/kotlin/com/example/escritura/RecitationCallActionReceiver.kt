package com.github.el_apps.daily_manna

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class RecitationCallActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Never start a service from an action: stale notifications cannot revive a session.
        RecitationCallService.dispatch(
            intent.getStringExtra(RecitationCallService.SESSION_ID), intent.action,
        )
    }
}
