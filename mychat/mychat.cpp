/*  MyChat - Sample videochat module for Moment Video Server
    Copyright (C) 2011 Dmitry Shatrov

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/


#include <libmary/libmary.h>

#include <moment/module_init.h>
#include <moment/api.h>

// DEBUG
#include <moment/libmoment.h>


using namespace M;


namespace MyChat {

class MyChat : public Object
{
private:
    StateMutex mutex;

    class ClientSession : public Referenced
    {
    public:
	bool valid;

	MyChat *mychat;

	MomentClientSession *srv_session;
	MomentStream *srv_in_stream;
	MomentStream *srv_out_stream;

	ClientSession *peer_session;
	bool in_session_hash;

	StringHash< Ref<ClientSession> >::EntryKey hash_key;
	List< Ref<ClientSession> >::Element *list_el;

	bool mic_on;
	bool cam_on;

        bool auth_passed;
        Timers::TimerKey auth_timer;
    };

    typedef StringHash< Ref<ClientSession> > ClientSessionHash;

    mt_const Moment::MomentServer *moment;
    mt_const Timers *timers;

    mt_const bool auth_required;
    mt_const Ref<String> auth_secret_key;
    mt_const Time auth_timeout;

    mt_mutex (mutex) ClientSessionHash session_hash;
    mt_mutex (mutex) List< Ref<ClientSession> > linked_sessions;

    static int startWatching (char const    *stream_name_buf,
                              size_t         stream_name_len,
                              void          *_session,
                              void          *_self,
                              MomentStartWatchingResultCallback cb,
                              void          *cb_data,
                              MomentStream **ret_stream);

    static int startStreaming (char const          *stream_name_buf,
                               size_t               stream_name_len,
                               MomentStream        *stream,
                               MomentRecordingMode  rec_mode,
                               void                *_session,
                               void                *_self,
                               MomentStartStreamingResultCallback const /* cb */,
                               void                * const /* cb_data */,
                               MomentResult        * const ret_res);

    static void rtmpCommandMessage (MomentMessage *msg,
				    void          *_session,
				    void          *_self);

    mt_mutex (mutex) void destroyClientSession (ClientSession *session);

    mt_unlocks (mutex) void destroyClientSession_forceDisconnect (ClientSession *session);

    static void authTimerTick (void *_session);

    static void clientConnected (MomentClientSession  *srv_session,
				 char const           *app_name_buf,
				 size_t                app_name_len,
				 char const           *full_app_name_buf,
				 size_t                full_app_name_len,
				 void                **ret_client_data,
				 void                 *_self);

    static void clientDisconnected (void *_session,
				    void *_self);

public:
    void init (char const *prefix_buf,
	       size_t      prefix_len);

    MyChat ()
        : auth_timeout (60)
    {
    }

  // TODO ~MyChat() destructor
};

static MyChat glob_mychat;

static unsigned char glob_peer_disconnected_buf [512];
static size_t glob_peer_disconnected_len;

static unsigned char glob_end_call_buf [512];
static size_t glob_end_call_len;

static unsigned char glob_mic_off_buf [512];
static size_t glob_mic_off_len;

static unsigned char glob_cam_off_buf [512];
static size_t glob_cam_off_len;

static char const peer_connected_str    [] = "mychat_peer_connected";
static char const peer_disconnected_str [] = "mychat_peer_disconnected";
static char const end_call_str [] = "mychat_end_call";
static char const auth_str     [] = "mychat_auth";

static char const mic_on_str  [] = "mychat_mic_on";
static char const mic_off_str [] = "mychat_mic_off";
static char const cam_on_str  [] = "mychat_cam_on";
static char const cam_off_str [] = "mychat_cam_off";

mt_mutex (mutex) void MyChat::destroyClientSession (ClientSession * const session)
{
    logD_ (_func, "session 0x", fmt_hex, (UintPtr) session);

    if (!session->valid) {
	return;
    }
    session->valid = false;

    MyChat * const self = session->mychat;

    if (session->auth_timer) {
        self->timers->deleteTimer (session->auth_timer);
        session->auth_timer = NULL;
    }

    if (session->peer_session) {
	ClientSession * const peer_session = session->peer_session;
	session->peer_session->peer_session = NULL;
	session->peer_session = NULL;
	self->destroyClientSession (peer_session);
    }

    moment_client_session_unref (session->srv_session);

    if (session->srv_in_stream)
        moment_stream_unref (session->srv_in_stream);

    moment_stream_unref (session->srv_out_stream);

    if (session->in_session_hash)
	self->session_hash.remove (session->hash_key);
    else
	self->linked_sessions.remove (session->list_el);

}

mt_unlocks (mutex) void MyChat::destroyClientSession_forceDisconnect (ClientSession * const session)
{
    if (!session->valid) {
        mutex.unlock ();
        return;
    }

    MomentClientSession *peer_srv_session = NULL;
    if (session->peer_session) {
        peer_srv_session = session->peer_session->srv_session;
        moment_client_session_ref (peer_srv_session);
    }

    MomentClientSession * const srv_session = session->srv_session;
    moment_client_session_ref (srv_session);

    destroyClientSession (session);
    mutex.unlock ();

    if (peer_srv_session) {
	moment_client_send_rtmp_command_message (peer_srv_session,
						 glob_end_call_buf,
						 glob_end_call_len);

        moment_client_session_disconnect (peer_srv_session);
        moment_client_session_unref (peer_srv_session);
    }

    moment_client_session_disconnect (srv_session);
    moment_client_session_unref (srv_session);
}

void MyChat::authTimerTick (void * const _session)
{
    ClientSession * const session = static_cast <ClientSession*> (_session);
    MyChat * const self = session->mychat;

    logD_ (_func, "auth timeout");

    self->mutex.lock ();

    self->timers->deleteTimer (session->auth_timer);
    session->auth_timer = NULL;

    self->destroyClientSession_forceDisconnect (session);

    self->mutex.unlock ();
}

void MyChat::clientConnected (MomentClientSession  * const srv_session,
			      char const           * const app_name_buf,
			      size_t                 const app_name_len,
			      char const           * const full_app_name_buf,
			      size_t                 const full_app_name_len,
			      void                ** const ret_client_data,
			      void                 * const _self)
{
    logD_ (_func, "app ", ConstMemory (app_name_buf, app_name_len), ", "
	   "full_app ", ConstMemory (full_app_name_buf, full_app_name_len));

    MyChat * const self = static_cast <MyChat*> (_self);

    Ref<ClientSession> session = grab (new ClientSession);
    session->valid = true;
    session->mychat = self;
    session->peer_session = NULL;
    session->in_session_hash = false;

    session->mic_on = true;
    session->cam_on = true;

    session->auth_passed = false;
    if (!self->auth_required)
        session->auth_passed = true;

    session->auth_timer = NULL;

    session->srv_session = srv_session;
    moment_client_session_ref (srv_session);

    unsigned char peer_connected_msg_buf [512];
    size_t peer_connected_msg_len;
    {
	MomentAmfEncoder * const encoder = moment_amf_encoder_new_AMF0 ();
	moment_amf_encoder_add_string (encoder, peer_connected_str, sizeof (peer_connected_str) - 1);
	moment_amf_encoder_add_number (encoder, 0.0);
	moment_amf_encoder_add_null_object (encoder);
	if (moment_amf_encoder_encode (encoder, peer_connected_msg_buf, sizeof (peer_connected_msg_buf), &peer_connected_msg_len))
	    abort ();

	moment_amf_encoder_delete (encoder);
    }

    self->mutex.lock ();

    ClientSessionHash::EntryKey session_key = self->session_hash.lookup (ConstMemory (app_name_buf, app_name_len));
    if (session_key) {
	logD_ (_func, "Connecting clients, dialogue name: ", ConstMemory (app_name_buf, app_name_len));

	Ref<ClientSession> peer_session = session_key.getData();
	self->session_hash.remove (session_key);
	peer_session->in_session_hash = false;

	session->srv_in_stream = peer_session->srv_out_stream;
	moment_stream_ref (session->srv_in_stream);
	session->srv_out_stream = peer_session->srv_in_stream;
	moment_stream_ref (session->srv_out_stream);
	logD_ (_func, "REFCOUNT: ", ((Moment::VideoStream*) session->srv_in_stream)->getRefCount());

	session->peer_session = peer_session;
	peer_session->peer_session = session;

	session->list_el = self->linked_sessions.append (session);
	peer_session->list_el = self->linked_sessions.append (peer_session);

	logD_ (_func, "sending peer_connected");
	moment_client_send_rtmp_command_message (srv_session, peer_connected_msg_buf, peer_connected_msg_len);
	moment_client_send_rtmp_command_message (peer_session->srv_session, peer_connected_msg_buf, peer_connected_msg_len);

	if (!peer_session->mic_on) {
	    logD_ (_func, "sending mychat_mic_off");
	    moment_client_send_rtmp_command_message (srv_session, glob_mic_off_buf, glob_mic_off_len);
	}

	if (!peer_session->cam_on) {
	    logD_ (_func, "sending mychat_cam_off");
	    moment_client_send_rtmp_command_message (srv_session, glob_cam_off_buf, glob_cam_off_len);
	}
    } else {
	session->hash_key = self->session_hash.add (ConstMemory (app_name_buf, app_name_len), session);
	session->in_session_hash = true;

	session->srv_in_stream = moment_create_stream ();
	session->srv_out_stream = moment_create_stream ();
	logD_ (_func, "NEW REFCOUNT: ", ((Moment::VideoStream*) session->srv_in_stream)->getRefCount());
    }

    if (self->auth_required && self->auth_timeout != 0) {
        session->auth_timer = self->timers->addTimer (CbDesc<Timers::TimerCallback> (authTimerTick,
                                                                                     session,
                                                                                     self    /* coderef_container */,
                                                                                     session /* ref_data */),
                                                      self->auth_timeout,
                                                      false /* periodical */,
                                                      false /* auto_delete */);
    }

    self->mutex.unlock ();

    *ret_client_data = static_cast <void*> (session);
    session->ref();
}

void MyChat::clientDisconnected (void * const _session,
				 void * const _self)
{
    logD_ (_func_);

    MyChat * const self = static_cast <MyChat*> (_self);
    ClientSession * const session = static_cast <ClientSession*> (_session);

    self->mutex.lock ();
    if (!session->valid) {
	self->mutex.unlock ();
	return;
    }

    MomentClientSession *peer_srv_session = NULL;

    logD_ (_func, "session->peer_session: 0x", fmt_hex, (UintPtr) session->peer_session);
    if (session->peer_session) {
	ClientSession * const peer_session = session->peer_session;

	peer_srv_session = peer_session->srv_session;
	moment_client_session_ref (peer_srv_session);
    }
    self->destroyClientSession (session);
    self->mutex.unlock ();

    logD_ (_func, "peer_srv_session: 0x", fmt_hex, (UintPtr) peer_srv_session);
    if (peer_srv_session) {
	logD_ (_func, "sending mychat_peer_disconnected message");
	moment_client_send_rtmp_command_message (peer_srv_session,
						 glob_peer_disconnected_buf,
						 glob_peer_disconnected_len);

	moment_client_session_disconnect (peer_srv_session);
	moment_client_session_unref (peer_srv_session);
    }

    session->unref();
}

int MyChat::startWatching (char const    * const stream_name_buf,
                           size_t          const stream_name_len,
                           void          * const _session,
                           void          * const _self,
                           MomentStartWatchingResultCallback const /* cb */,
                           void          * const /* cb_data */,
                           MomentStream ** const ret_stream)
{
    *ret_stream = NULL;

    logD_ (_func, ConstMemory (stream_name_buf, stream_name_len));

    MyChat * const self = static_cast <MyChat*> (_self);
    ClientSession * const session = static_cast <ClientSession*> (_session);

    self->mutex.lock ();

    if (self->auth_required && !session->auth_passed) {
        mt_unlocks (mutex) self->destroyClientSession_forceDisconnect (session);
        *ret_stream = NULL;
        return 1;
    }

    self->mutex.unlock ();

    *ret_stream = session->srv_out_stream;
    return 1;
}

int MyChat::startStreaming (char const          * const stream_name_buf,
                            size_t                const stream_name_len,
                            MomentStream        * const stream,
                            MomentRecordingMode   const /* rec_mode */,
                            void                * const _session,
                            void                * const _self,
                            MomentStartStreamingResultCallback const /* cb */,
                            void                * const /* cb_data */,
                            MomentResult        * const ret_res)
{
    *ret_res = MomentResult_Failure;

    logD_ (_func, ConstMemory (stream_name_buf, stream_name_len));

    MyChat * const self = static_cast <MyChat*> (_self);
    ClientSession * const session = static_cast <ClientSession*> (_session);

    self->mutex.lock ();

    if (self->auth_required && !session->auth_passed) {
        mt_unlocks (mutex) self->destroyClientSession_forceDisconnect (session);
        *ret_res = MomentResult_Failure;
        return 1;
    }

    moment_stream_bind_to_stream (session->srv_in_stream,
                                  stream /* bind_audio_stream */,
                                  stream /* bind_video_stream */,
                                  1      /* bind_audio */,
                                  1      /* bind_video */);

    self->mutex.unlock ();

    *ret_res = MomentResult_Success;
    return 1;
}

void MyChat::rtmpCommandMessage (MomentMessage * const msg,
				 void          * const _session,
				 void          * const _self)
{
    MomentAmfDecoder * const decoder = moment_amf_decoder_new_AMF0 (msg);

  {
    MyChat * const self = static_cast <MyChat*> (_self);
    ClientSession * const session = static_cast <ClientSession*> (_session);

    logD_ (_func_);

    self->mutex.lock ();

    char method_name [512];
    size_t method_name_len;
    if (!moment_amf_decode_string (decoder,
				   method_name,
				   sizeof (method_name),
				   &method_name_len,
				   NULL /* ret_full_len */))
    {
        if (method_name_len == sizeof (auth_str) - 1
            && !memcmp (method_name, auth_str, sizeof (auth_str) -1 ))
        {
	    if (moment_amf_decode_number (decoder, NULL))
		logW_ (_func, "Could not skip transaction id");

	    if (moment_amf_decoder_skip_object (decoder))
		logW_ (_func, "Could not skip command object");

            if (!self->auth_required) {
                self->mutex.unlock ();
                goto _return;
            }

            if (self->auth_secret_key.isNull()) {
                self->mutex.unlock ();
                logE_ (_func, "no secret key");
                goto _return;
            }

            char hash_from_client_buf [1024];
            size_t hash_from_client_len;
            if (moment_amf_decode_string (decoder,
                                          hash_from_client_buf,
                                          sizeof (hash_from_client_buf),
                                          &hash_from_client_len,
                                          NULL /* ret_full_len */))
            {
                logW_ (_func, auth_str, ": could not decode auth hash");
                mt_unlocks (mutex) self->destroyClientSession_forceDisconnect (session);
                goto _return;
            }

            ConstMemory client_text;
            ConstMemory client_hash;
            {
                unsigned long i;
                for (i = 0; i < hash_from_client_len; ++i) {
                    if (hash_from_client_buf [i] == '|')
                        break;
                }

                if (i >= hash_from_client_len) {
                    logW_ (_func, auth_str, ": bad auth string from client: no '|' separator");
                    mt_unlocks (mutex) self->destroyClientSession_forceDisconnect (session);
                    goto _return;
                }

                client_text = ConstMemory (hash_from_client_buf, i);
                client_hash = ConstMemory (hash_from_client_buf + i + 1, hash_from_client_len - i - 1);
            }

            {
                unsigned i = 0;
                for (; i < 3; ++i) {
                    Ref<String> const src_text = makeString (((Uint64) getUnixtime() + 1800) / 3600 - i /* auth timestamp */,
                                                             " ",
                                                             client_text,
                                                             self->auth_secret_key->mem());
                    unsigned char hash_buf [32];
                    getMd5HexAscii (src_text->mem(), Memory::forObject (hash_buf));
                    logD_ (_func, "src_text: ", src_text, ", md5: ", ConstMemory::forObject (hash_buf));
        // Old dummy variant
        //            if (!equal (ConstMemory (hash_from_client_buf, hash_from_client_len),
        //                        self->auth_secret_key->mem()))
                    if (equal (ConstMemory::forObject (hash_buf), client_hash))
                        break;
                }

                if (i >= 3) {
                    logW_ (_func, auth_str, ": auth check failed");
                    mt_unlocks (mutex) self->destroyClientSession_forceDisconnect (session);
                    goto _return;
                }
            }

            logD_ (_func, auth_str, ": auth check passed");
            session->auth_passed = true;
            if (session->auth_timer) {
                self->timers->deleteTimer (session->auth_timer);
                session->auth_timer = NULL;
            }

            self->mutex.unlock ();
            goto _return;
        }

        if (self->auth_required && !session->auth_passed) {
            self->mutex.unlock ();
            logW_ (_func, "not auth, command ignored: ", ConstMemory (method_name, method_name_len));
            goto _return;
        }

        logD_ (_func, ConstMemory (method_name, method_name_len));
	if (method_name_len == sizeof (mic_on_str) - 1
	    && !memcmp (method_name, mic_on_str, sizeof (mic_on_str) - 1))
	{
	    session->mic_on = true;
	} else
	if (method_name_len == sizeof (mic_off_str) - 1
	    && !memcmp (method_name, mic_off_str, sizeof (mic_off_str) - 1))
	{
	    session->mic_on = false;
	} else
	if (method_name_len == sizeof (cam_on_str) - 1
	    && !memcmp (method_name, cam_on_str, sizeof (cam_on_str) - 1))
	{
	    session->cam_on = true;
	} else
	if (method_name_len == sizeof (cam_off_str) - 1
	    && !memcmp (method_name, cam_off_str, sizeof (cam_off_str) - 1))
	{
	    session->cam_on = false;
	} else
	if (method_name_len == sizeof (end_call_str) - 1
	    && !memcmp (method_name, end_call_str, sizeof (end_call_str) - 1))
	{
            mt_unlocks (mutex) self->destroyClientSession_forceDisconnect (session);
	    goto _return;
	}
    }

    if (!session->valid
	|| !session->peer_session
	|| !session->peer_session->valid)
    {
	self->mutex.unlock ();
	goto _return;
    }

    assert (session->peer_session->srv_session);
    MomentClientSession * const srv_session = session->peer_session->srv_session;
    moment_client_session_ref (srv_session);

    self->mutex.unlock ();

    moment_client_send_rtmp_command_message_passthrough (srv_session, msg);
    moment_client_session_unref (srv_session);
  }

_return:
    moment_amf_decoder_delete (decoder);
}

void MyChat::init (char const * const prefix_buf,
		   size_t       const prefix_len)
{
    logD_ (_func_);

    // TODO Use C API for config access.
    moment = Moment::MomentServer::getInstance();
    MConfig::Config * const config = moment->getConfig ();
    timers = moment->getServerApp()->getMainThreadContext()->getTimers();

    {
        ConstMemory const opt_name = "mychat/auth_required";
        MConfig::BooleanValue const val = config->getBoolean (opt_name);
        if (val == MConfig::Boolean_Invalid) {
            logE_ (_func, "Invalid value for ", opt_name, ": ", config->getString (opt_name));
            return;
        }

        if (val != MConfig::Boolean_True) {
            auth_required = false;
        } else {
            logD_ (_func, "auth required");
            auth_required = true;
        }
    }

    {
        ConstMemory const opt_name = "mychat/auth_secret_key";
        bool is_set = false;
        auth_secret_key = grab (new String (config->getString (opt_name, &is_set)));
        if (auth_required && !is_set) {
            logE_ (_func, "Secret authentication key not specified (", opt_name, " config option)");
            return;
        }
    }

    {
        ConstMemory const opt_name = "mychat/auth_timeout";
        MConfig::GetResult const res = config->getUint64_default (
                opt_name, &auth_timeout, auth_timeout);
        if (!res) {
            logE_ (_func, "Invalid value for ", opt_name, ": ", config->getString (opt_name));
            return;
        }
    }

    {
	MomentAmfEncoder * const encoder = moment_amf_encoder_new_AMF0 ();
	moment_amf_encoder_add_string (encoder, peer_disconnected_str, sizeof (peer_disconnected_str) - 1);
	moment_amf_encoder_add_number (encoder, 0.0);
	moment_amf_encoder_add_null_object (encoder);
	if (moment_amf_encoder_encode (encoder,
				       glob_peer_disconnected_buf,
				       sizeof (glob_peer_disconnected_buf),
				       &glob_peer_disconnected_len))
	{
	    abort ();
	}

        moment_amf_encoder_reset (encoder);
        moment_amf_encoder_add_string (encoder, end_call_str, sizeof (end_call_str) - 1);
        moment_amf_encoder_add_number (encoder, 0.0);
        moment_amf_encoder_add_null_object (encoder);
        if (moment_amf_encoder_encode (encoder, glob_end_call_buf, sizeof (glob_end_call_buf), &glob_end_call_len))
            abort ();

	moment_amf_encoder_reset (encoder);
	moment_amf_encoder_add_string (encoder, mic_off_str, sizeof (mic_off_str) - 1);
	moment_amf_encoder_add_number (encoder, 0.0);
	moment_amf_encoder_add_null_object (encoder);
	if (moment_amf_encoder_encode (encoder, glob_mic_off_buf, sizeof (glob_mic_off_buf), &glob_mic_off_len))
	    abort ();

	moment_amf_encoder_reset (encoder);
	moment_amf_encoder_add_string (encoder, cam_off_str, sizeof (cam_off_str) - 1);
	moment_amf_encoder_add_number (encoder, 0.0);
	moment_amf_encoder_add_null_object (encoder);
	if (moment_amf_encoder_encode (encoder, glob_cam_off_buf, sizeof (glob_cam_off_buf), &glob_cam_off_len))
	    abort ();

	moment_amf_encoder_delete (encoder);
    }

    MomentClientHandler *ch = moment_client_handler_new ();
    moment_client_handler_set_connected (ch, clientConnected, this);
    moment_client_handler_set_disconnected (ch, clientDisconnected, this);
    moment_client_handler_set_start_watching (ch, startWatching, this);
    moment_client_handler_set_start_streaming (ch, startStreaming, this);
    moment_client_handler_set_rtmp_command_message (ch, rtmpCommandMessage, this);

    moment_add_client_handler (ch, prefix_buf, prefix_len);

    moment_client_handler_delete (ch);
}

}

extern "C" {

void moment_module_init ()
{
    char const prefix [] = "mychat";
    MyChat::glob_mychat.init (prefix, sizeof (prefix) - 1);
}

void moment_module_unload ()
{
    logD_ (_func_);
}

}

