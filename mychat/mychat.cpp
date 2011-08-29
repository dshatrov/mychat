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
#include <mycpp/list.h>

#include <moment/module_init.h>
#include <moment/api.h>

// DEBUG
#include <moment/libmoment.h>


using namespace M;


namespace MyChat {

class MyChat
{
private:
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
	MyCpp::List< Ref<ClientSession> >::Element *list_el;
    };

    typedef StringHash< Ref<ClientSession> > ClientSessionHash;

    mt_mutex (mutex) ClientSessionHash session_hash;
    mt_mutex (mutex) MyCpp::List< Ref<ClientSession> > linked_sessions;

    Mutex mutex;

    static MomentStream* startWatching (char const *stream_name_buf,
					size_t      stream_name_len,
					void       *_session,
					void       *_self);

    static MomentStream* startStreaming (char const *stream_name_buf,
					 size_t      stream_name_len,
					 void       *_session,
					 void       *_self);

    mt_mutex (mutex) void destroyClientSession (ClientSession *session);

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

  // TODO ~MyChat() destructor
};

MyChat glob_mychat;

mt_mutex (mutex) void MyChat::destroyClientSession (ClientSession * const session)
{
    logD_ (_func, "session 0x", fmt_hex, (UintPtr) session);

    if (!session->valid) {
	return;
    }
    session->valid = false;

    MyChat * const self = session->mychat;

    moment_client_session_unref (session->srv_session);

    moment_stream_unref (session->srv_in_stream);
    moment_stream_unref (session->srv_out_stream);

    if (session->in_session_hash)
	self->session_hash.remove (session->hash_key);
    else
	self->linked_sessions.remove (session->list_el);

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

    session->srv_session = srv_session;
    moment_client_session_ref (srv_session);

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
    } else {
	session->hash_key = self->session_hash.add (ConstMemory (app_name_buf, app_name_len), session);
	session->in_session_hash = true;

	session->srv_in_stream = moment_create_stream ();
	session->srv_out_stream = moment_create_stream ();
	logD_ (_func, "NEW REFCOUNT: ", ((Moment::VideoStream*) session->srv_in_stream)->getRefCount());
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
    if (session->peer_session) {
	ClientSession * const peer_session = session->peer_session;
	session->peer_session->peer_session = NULL;
	session->peer_session = NULL;
	self->destroyClientSession (peer_session);
    }
    self->destroyClientSession (session);
    self->mutex.unlock ();

    session->unref();
}

MomentStream* MyChat::startWatching (char const *stream_name_buf,
				     size_t      stream_name_len,
				     void       *_session,
				     void       * /* _self */)
{
    logD_ (_func, ConstMemory (stream_name_buf, stream_name_len));
    ClientSession * const session = static_cast <ClientSession*> (_session);
    return session->srv_out_stream;
}

MomentStream* MyChat::startStreaming (char const *stream_name_buf,
				      size_t      stream_name_len,
				      void       *_session,
				      void       * /* _self */)
{
    logD_ (_func, ConstMemory (stream_name_buf, stream_name_len));
    ClientSession * const session = static_cast <ClientSession*> (_session);
    return session->srv_in_stream;
}

void MyChat::init (char const * const prefix_buf,
		   size_t       const prefix_len)
{
    logD_ (_func_);

    MomentClientHandler *ch = moment_client_handler_new ();
    moment_client_handler_set_connected (ch, clientConnected, this);
    moment_client_handler_set_disconnected (ch, clientDisconnected, this);
    moment_client_handler_set_start_watching (ch, startWatching, this);
    moment_client_handler_set_start_streaming (ch, startStreaming, this);

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

