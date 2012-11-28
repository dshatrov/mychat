package {

import flash.external.ExternalInterface;
import flash.display.Sprite;
import flash.display.StageScaleMode;
import flash.display.StageAlign;
import flash.display.Loader;
import flash.media.Camera;
import flash.media.Microphone;
import flash.media.Video;
import flash.media.SoundTransform;
import flash.media.SoundCodec;
import flash.media.H264VideoStreamSettings;
import flash.media.H264Level;
import flash.media.H264Profile;
import flash.net.NetConnection;
import flash.net.NetStream;
import flash.net.ObjectEncoding;
import flash.net.URLRequest;
import flash.events.Event;
import flash.events.NetStatusEvent;
import flash.events.MouseEvent;
import flash.utils.setInterval;
import flash.utils.clearInterval;

public class MyChat extends Sprite
{
    private var auth_str: String;

    private var first_reconnect_interval : Number;

    private var my_video_normal_width  : Number;
    private var my_video_normal_height : Number;
    private var my_video_fullscreen_width  : Number;
    private var my_video_fullscreen_height : Number;

    private var cam : Camera;
    private var mic : Microphone;

    private var peer_video : Video;
    private var my_video : Video;

    private var conn_closed : Boolean;
    private var conn : NetConnection;
    private var stream : NetStream;

    private var redialing : Boolean;
    private var new_call : Boolean;
    private var show_connected_status_msg : Boolean;

    private var reconnect_interval : uint;
    private var reconnect_timer : uint;
    private var reconnect_timer_active : Boolean;

    private var uri : String;
    private var stream_name : String;

    private var buttons_visible : Boolean;

    private var mic_on : Boolean;
    private var cam_on : Boolean;
    private var sound_on : Boolean;

    // If true, then horizontal mode is enabled.
    private var horizontal_mode : Boolean;

    private var peer_mic_on : Boolean;
    private var peer_cam_on : Boolean;

    private var peer_mic_off_mark : LoadedElement;
    private var peer_cam_off_mark : LoadedElement;
    private var my_mic_off_mark   : LoadedElement;
    private var my_cam_off_mark   : LoadedElement;

    private var roll_button          : LoadedElement;
    private var unroll_button        : LoadedElement;
    private var new_call_button      : LoadedElement;
    private var redial_button        : LoadedElement;
    private var end_call_button      : LoadedElement;
    private var end_call_grey_button : LoadedElement;
    private var mic_button_on        : LoadedElement;
    private var mic_button_off       : LoadedElement;
    private var cam_button_on        : LoadedElement;
    private var cam_button_off       : LoadedElement;
    private var sound_button_on      : LoadedElement;
    private var sound_button_off     : LoadedElement;
    private var fullscreen_button    : LoadedElement;
    private var horizontal_button    : LoadedElement;

    private var hide_buttons_timer : uint;
    private var hide_buttons_timer_active : Boolean;

    private var splash : LoadedElement;

    private var stage_width : int;
    private var stage_height : int;

    private function sendChatMessage (msg : String) : void
    {
	conn.call ("mychat_chat", null, msg);
    }

    public function addChatMessage (msg : String) : void
    {
	ExternalInterface.call ("addChatMessage", msg);
    }

    public function addStatusMessage (msg : String) : void
    {
	ExternalInterface.call ("addStatusMessage", msg);
    }

    public function addRedStatusMessage (msg : String) : void
    {
	ExternalInterface.call ("addRedStatusMessage", msg);
    }

    public function addGreenStatusMessage (msg : String) : void
    {
	ExternalInterface.call ("addGreenStatusMessage", msg);
    }

    public function showSplash () : void
    {
	peer_video.visible = false;
	splash.setVisible (true);
    }

    public function showPeerVideo () : void
    {
	splash.setVisible (false);
	peer_video.visible = true;
    }

    public function peerMicOn () : void
    {
//	addStatusMessage ("peerMicOn");
	peer_mic_on = true;
	repositionButtons ();
	peer_mic_off_mark.setVisible (false);
    }

    public function peerMicOff () : void
    {
//	addStatusMessage ("peerMicOff");
	peer_mic_on = false;
	repositionButtons ();
	peer_mic_off_mark.setVisible (true);
    }

    public function peerCamOn () : void
    {
//	addStatusMessage ("peerCamOn");
	peer_cam_on = true;
	repositionButtons ();
	peer_cam_off_mark.setVisible (false);
	showPeerVideo ();
    }

    public function peerCamOff () : void
    {
//	addStatusMessage ("peerCamOff");
	peer_cam_on = false;
	repositionButtons ();
	peer_cam_off_mark.setVisible (true);
	showSplash ();
    }

    private function onStreamNetStatus (event : NetStatusEvent) : void
    {
//	addStatusMessage ("onStreamNetStatus: " + event.info.code);
    }

    private function doConnect (code : String, reconnect : Boolean) : void
    {
//	addStatusMessage ("doConnect: code: \"" + code + "\", reconnect: " + reconnect);

	// TODO Close the previous connection explicitly.

	ExternalInterface.call ("blockChat");

	stream_name = code;

	if (!reconnect) {
	    reconnect_interval = first_reconnect_interval;
	} else {
	    if (reconnect_interval == first_reconnect_interval) {
		reconnect_interval = 5000;
		clearInterval (reconnect_timer);
		reconnect_timer = setInterval (reconnectTick, reconnect_interval);
	    }
	}

	conn_closed = false;
	if (buttons_visible) {
	    end_call_button.setVisible (true);
	}
	end_call_grey_button.setVisible (false);

	conn = new NetConnection ();
	conn.client = new ConnClient (this);

	conn.objectEncoding = ObjectEncoding.AMF0;
	conn.addEventListener (NetStatusEvent.NET_STATUS, onConnNetStatus);
	conn.connect (uri + '/' + code);
    }

    private function connect (code : String) : void
    {
	new_call_button.setVisible (false);
	showSplash ();
	if (!new_call) {
	    addStatusMessage ("Соединение с сервером " + uri + " ...");
	    show_connected_status_msg = true;
	}
	doConnect (code, false /* reconnect */);
    }

    private function reconnectTick () : void
    {
	doConnect (stream_name, true /* reconnect */);
    }

    private function onConnNetStatus (event : NetStatusEvent) : void
    {
//	addStatusMessage ("onConnNetStatus: " + event.info.code);

	if (event.info.code == "NetConnection.Connect.Success") {
	    if (reconnect_timer_active) {
		clearInterval (reconnect_timer);
		reconnect_timer_active = false;
	    }
	    reconnect_interval = first_reconnect_interval;

            if (auth_str)
                conn.call ("mychat_auth", null, auth_str);

	    if (show_connected_status_msg) {
//		addStatusMessage ("Соединение с сервером установлено");
		show_connected_status_msg = false;
	    }
	    addStatusMessage ("Ожидание собеседника...");

	    if (!mic_on)
		conn.call ("mychat_mic_off", null);

	    if (!cam_on)
		conn.call ("mychat_cam_off", null);

	    stream = new NetStream (conn);

	    stream.bufferTime = 0; // Live stream
	    // This does not work with older versions of Flash player
	    // stream.bufferTimeMax = 0.33;

	    stream.addEventListener (NetStatusEvent.NET_STATUS, onStreamNetStatus);

	    if (!sound_on)
		doTurnSoundOff ();

	    /* Unnecessary
	    {
		var vx : Number = peer_video.x;
		var vy : Number = peer_video.y;
		var vwidth :  Number = peer_video.width;
		var vheight : Number = peer_video.height;
		removeChild (peer_video);
		peer_video = new Video ();
		peer_video.x = vx;
		peer_video.y = vy;
		peer_video.width = vwidth;
		peer_video.height = vheight;
		addChild (peer_video);
		setChildIndex (peer_video, getChildIndex (splash.obj));
	    }
	    */

// Unnecessary	    peer_video.clear ();
	    peer_video.attachNetStream (stream);

	    stream.play (stream_name);
	    stream.publish (stream_name);

	    if (cam && cam_on) {
                /*
                var avc_opts : H264VideoStreamSettings = new H264VideoStreamSettings ();
                avc_opts.setProfileLevel (H264Profile.BASELINE, H264Level.LEVEL_3_1);
                stream.videoStreamSettings = avc_opts;
                */

		stream.attachCamera (cam);
            }

	    if (mic && mic_on)
		stream.attachAudio (mic);
	} else
	// TODO Rejected, AppShutDown error codes.
	if (event.info.code == "NetConnection.Connect.Closed" ||
	    event.info.code == "NetConnection.Connect.Failed")
	{
	    if (!reconnect_timer_active &&
		event.info.code == "NetConnection.Connect.Failed")
	    {
		addRedStatusMessage ("Ошибка соединения с сервером");
	    }

	    if (redialing)
		return;

	    if (!conn_closed &&
		event.info.code == "NetConnection.Connect.Closed")
	    {
		addRedStatusMessage ("Соединение с сервером разорвано");
	    }
	    show_connected_status_msg = false;

	    ExternalInterface.call ("blockChat");

	    if (!conn_closed && !reconnect_timer_active) {
		addStatusMessage ("Повторное соединение...");

		if (reconnect_interval == 0) {
		    doConnect (stream_name, true /* reconnect */);
		    return;
		}

//		addStatusMessage ("onConnNetStatus: starting reconnect timer, interval: " + reconnect_interval);
		reconnect_timer = setInterval (reconnectTick, reconnect_interval);
		reconnect_timer_active = true;
	    }
	}
    }

    private function newCall (event : MouseEvent) : void
    {
	new_call = true;

//	addStatusMessage ("newCall");
	ExternalInterface.call ("newCall");

	if (stage.displayState == "fullScreen")
	    stage.displayState = "normal";

	addStatusMessage ("Новый вызов...");
    }

    private function doRedial () : void
    {
	if (reconnect_timer_active) {
	    clearInterval (reconnect_timer);
	    reconnect_timer_active = false;
	}

	peer_mic_off_mark.setVisible (false);
	peer_cam_off_mark.setVisible (false);

	new_call_button.setVisible (false);

	redialing = true;
	conn.close ();
	redialing = false;

	doConnect (stream_name, false /* reconnect */);
    }

    private function redial (event : MouseEvent) : void
    {
	showSplash ();
	peer_video.clear ();
	addStatusMessage ("Повторный вызов...");
	doRedial ();
    }

    private function doEndCall () : void
    {
	ExternalInterface.call ("blockChat");

	if (reconnect_timer_active) {
	    clearInterval (reconnect_timer);
	    reconnect_timer_active = false;
	}

	conn_closed = true;
	conn.close ();

	peer_mic_off_mark.setVisible (false);
	peer_cam_off_mark.setVisible (false);

	if (buttons_visible) {
	    end_call_grey_button.setVisible (true);
	}
	end_call_button.setVisible (false);

	peer_video.visible = false;
	splash.setVisible (false);

	// TODO Show "Call ended. Make another call" button.
	new_call_button.setVisible (true);

	peer_video.clear ();
    }

    private function endCall (event : MouseEvent) : void
    {
	conn.call ("mychat_end_call", null);
	doEndCall ();
	addRedStatusMessage ("Вызов завершён");
    }

    public function peerConnected () : void
    {
	ExternalInterface.call ("unblockChat");
	showPeerVideo ();
	addGreenStatusMessage ("Собеседник подключен");
    }

    public function peerDisconnected () : void
    {
	addRedStatusMessage ("Собеседник отключился");
//	addStatusMessage ("Ожидание собеседника...");
	doRedial ();
    }

    public function peerEndCall () : void
    {
	doEndCall ();
	addRedStatusMessage ("Собеседник завершил разговор");
    }

    private function rollMyVideo (event : MouseEvent) : void
    {
	my_video.visible = false;
	my_mic_off_mark.setVisible (false);
	my_cam_off_mark.setVisible (false);
	showButtons ();
    }

    private function unrollMyVideo (event : MouseEvent) : void
    {
	my_video.visible = true;

	if (!mic_on)
	    my_mic_off_mark.setVisible (true);

	if (!cam_on)
	    my_cam_off_mark.setVisible (true);

	showButtons ();
    }

    private function turnMicOn (event : MouseEvent) : void
    {
	stream.attachAudio (mic);
	mic_on = true;
	repositionButtons ();
	my_mic_off_mark.setVisible (false);
	showButtons ();
	conn.call ("mychat_mic_on", null);
    }

    private function turnMicOff (event : MouseEvent) : void
    {
	stream.attachAudio (null);
	mic_on = false;
	repositionButtons ();

	if (cam && my_video.visible)
	    my_mic_off_mark.setVisible (true);

	showButtons ();
	conn.call ("mychat_mic_off", null);
    }

    private function turnCamOn (event : MouseEvent) : void
    {
	stream.attachCamera (cam);
	cam_on = true;
	repositionButtons ();
	my_cam_off_mark.setVisible (false);
	showButtons ();
	conn.call ("mychat_cam_on", null);
    }

    private function turnCamOff (event : MouseEvent) : void
    {
	stream.attachCamera (null);
	cam_on = false;
	repositionButtons ();

	if (cam && my_video.visible)
	    my_cam_off_mark.setVisible (true);

	showButtons ();
	conn.call ("mychat_cam_off", null);
    }

    private function turnSoundOn (event : MouseEvent) : void
    {
	sound_on = true;
	showButtons ();

	/* SoundTransform works with a noticable delay */
	if (stream) {
//	    if (!stream.soundTransform)
		stream.soundTransform = new SoundTransform ();
//	    else
//		stream.soundTransform.volume = 1;
	}
    }

    private function doTurnSoundOff () : void
    {
	if (stream) {
//	    if (!stream.soundTransform)
		stream.soundTransform = new SoundTransform (0);
//	    else
//		stream.soundTransform.volume = 0;
	}
    }

    private function turnSoundOff (event : MouseEvent) : void
    {
	sound_on = false;
	showButtons ();

	doTurnSoundOff ();
    }

    private function toggleFullscreen (event : MouseEvent) : void
    {
	if (stage.displayState == "fullScreen")
	    stage.displayState = "normal";
	else
	    stage.displayState = "fullScreen";
    }

    private function toggleHorizontal (event : MouseEvent) : void
    {
	horizontal_mode = !horizontal_mode;
	repositionVideo ();
    }

    private function doResize () : void
    {
	stage_width  = stage.stageWidth;
	stage_height = stage.stageHeight;

	repositionVideo ();
	repositionButtons ();
	repositionSplash ();

	showButtons ();
    }

    private function repositionButtons () : void
    {
	peer_mic_off_mark.obj.x = 25;
	peer_mic_off_mark.obj.y = 25;

	peer_cam_off_mark.obj.x = peer_mic_on ? 25 : 90;
	peer_cam_off_mark.obj.y = 25;

	my_mic_off_mark.obj.x = 20;
	my_mic_off_mark.obj.y = (stage_height - my_video.height - 10) + 10;

	my_cam_off_mark.obj.x = 20 + (!mic_on ? my_mic_off_mark.obj.width + 10 : 0);
	my_cam_off_mark.obj.y = (stage_height - my_video.height - 10) + 10;


	roll_button.obj.x = my_video.x;
	roll_button.obj.y = my_video.y + my_video.height - roll_button.obj.height;

	unroll_button.obj.x = my_video.x;
	unroll_button.obj.y = my_video.y + my_video.height - unroll_button.obj.height;

	new_call_button.obj.x = (stage_width - new_call_button.obj.width) / 2;
	new_call_button.obj.y = (stage_height - new_call_button.obj.height) / 2;

	redial_button.obj.x = stage_width - redial_button.obj.width - 90;
	redial_button.obj.y = 20;

	end_call_button.obj.x = stage_width - end_call_button.obj.width - 20;
	end_call_button.obj.y = 20;

	end_call_grey_button.obj.x = end_call_button.obj.x;
	end_call_grey_button.obj.y = end_call_button.obj.y;

	horizontal_button.obj.x = stage_width - horizontal_button.obj.width - 20;
	horizontal_button.obj.y = stage_height - horizontal_button.obj.height - 90;

	fullscreen_button.obj.x = stage_width  - fullscreen_button.obj.width  - 20;
	fullscreen_button.obj.y = stage_height - fullscreen_button.obj.height - 20;

	sound_button_on.obj.x  = stage_width  - sound_button_on.obj.width   - 90;
	sound_button_on.obj.y  = stage_height - sound_button_on.obj.height  - 20;
	sound_button_off.obj.x = stage_width  - sound_button_off.obj.width  - 90;
	sound_button_off.obj.y = stage_height - sound_button_off.obj.height - 20;

	cam_button_on.obj.x  = stage_width  - cam_button_on.obj.width   - 160;
	cam_button_on.obj.y  = stage_height - cam_button_on.obj.height  -  20;
	cam_button_off.obj.x = stage_width  - cam_button_off.obj.width  - 160;
	cam_button_off.obj.y = stage_height - cam_button_off.obj.height -  20;

	mic_button_on.obj.x  = stage_width  - mic_button_on.obj.width   - 230;
	mic_button_on.obj.y  = stage_height - mic_button_on.obj.height  -  20;
	mic_button_off.obj.x = stage_width  - mic_button_off.obj.width  - 230;
	mic_button_off.obj.y = stage_height - mic_button_off.obj.height -  20;
    }

    private function repositionSplash () : void
    {
        splash.obj.x = (stage_width - splash.obj.width) / 2;
        splash.obj.y = (stage_height - splash.obj.height) / 2;
    }

    private function videoShouldBeHorizontal () : Boolean
    {
	if (stage_width == 0 || stage_height == 0)
	    return true;

	var x_aspect : Number = (0.0 + Number (peer_video.videoWidth))  / Number (stage_width);
	var y_aspect : Number = (0.0 + Number (peer_video.videoHeight)) / Number (stage_height);

	return x_aspect >= y_aspect;
    }

    private function repositionVideo () : void
    {
	if (horizontal_mode || videoShouldBeHorizontal()) {
	    peer_video.width = stage_width;
	    peer_video.height = stage_width * (peer_video.videoHeight / peer_video.videoWidth);
	    peer_video.x = 0;
	    peer_video.y = (stage_height - peer_video.height) / 2;
	} else {
	    peer_video.width = stage_height * (peer_video.videoWidth / peer_video.videoHeight);
	    peer_video.height = stage_height;
	    peer_video.x = (stage_width - peer_video.width) / 2;
	    peer_video.y = 0;
	}

	if (stage.displayState == "fullScreen") {
	    my_video.width  = my_video_fullscreen_width;
	    my_video.height = my_video_fullscreen_height;
	} else {
	    my_video.width  = my_video_normal_width;
	    my_video.height = my_video_normal_height;
	}

	my_video.x = 10;
	my_video.y = (stage_height - my_video.height - 10);
    }

    private function hideButtonsTick () : void
    {
	if (hide_buttons_timer_active) {
	    clearInterval (hide_buttons_timer);
	    hide_buttons_timer_active = false;
	}

	buttons_visible = false;
	roll_button.setVisible (false);
	unroll_button.setVisible (false);
	redial_button.setVisible (false);
	end_call_button.setVisible (false);
	end_call_grey_button.setVisible (false);
	mic_button_on.setVisible (false);
	mic_button_off.setVisible (false);
	cam_button_on.setVisible (false);
	cam_button_off.setVisible (false);
	sound_button_on.setVisible (false);
	sound_button_off.setVisible (false);
	fullscreen_button.setVisible (false);
	horizontal_button.setVisible (false);
    }

    private function showButtons () : void
    {
	buttons_visible = true;

	if (cam) {
	    if (my_video.visible) {
		roll_button.setVisible (true);
		unroll_button.setVisible (false);
	    } else {
		roll_button.setVisible (false);
		unroll_button.setVisible (true);
	    }
	} else {
	    roll_button.setVisible (false);
	    unroll_button.setVisible (false);
	}

	redial_button.setVisible (true);

	if (!conn_closed) {
	    end_call_button.setVisible (true);
	    end_call_grey_button.setVisible (false);
	} else {
	    end_call_grey_button.setVisible (true);
	    end_call_button.setVisible (false);
	}

	if (mic_on) {
	    mic_button_on.setVisible (true);
	    mic_button_off.setVisible (false);
	} else {
	    mic_button_on.setVisible (false);
	    mic_button_off.setVisible (true);
	}

	if (cam_on) {
	    cam_button_on.setVisible (true);
	    cam_button_off.setVisible (false);
	} else {
	    cam_button_on.setVisible (false);
	    cam_button_off.setVisible (true);
	}

	if (sound_on) {
	    sound_button_on.setVisible (true);
	    sound_button_off.setVisible (false);
	} else {
	    sound_button_on.setVisible (false);
	    sound_button_off.setVisible (true);
	}

	fullscreen_button.setVisible (true);

	if (peer_video.visible &&
	    !videoShouldBeHorizontal ())
	{
	    horizontal_button.setVisible (true);
	} else {
	    horizontal_button.setVisible (false);
	}
    }

    private function onMouseMove (event : MouseEvent) : void
    {
	if (hide_buttons_timer_active) {
	    clearInterval (hide_buttons_timer);
	    hide_buttons_timer_active = false;
	}

	if (!hide_buttons_timer_active) {
	    hide_buttons_timer = setInterval (hideButtonsTick, 5000);
	    hide_buttons_timer_active = true;
	}

	showButtons ();
    }

    private function loaderComplete (loader : Loader) : Boolean
    {
        if (loader.contentLoaderInfo
            && loader.contentLoaderInfo.bytesTotal > 0
            && loader.contentLoaderInfo.bytesTotal == loader.contentLoaderInfo.bytesLoaded)
        {
            return true;
        }

        return false;
    }

    private function doLoaderLoadComplete (loaded_element : LoadedElement) : void
    {
        repositionSplash ();
	repositionButtons ();
	loaded_element.allowVisible ();
    }

    private function loaderLoadCompleteHandler (loaded_element : LoadedElement) : Function
    {
	return function (event : Event) : void {
	    doLoaderLoadComplete (loaded_element);
	};
    }

    private function createLoadedElement (img_url  : String,
					  visible_ : Boolean) : LoadedElement
    {
	var loaded_element : LoadedElement;
	var loader : Loader;

	loader = new Loader ();

        loaded_element = new LoadedElement (visible_);
	loaded_element.obj = loader;

        loader.load (new URLRequest (img_url));
        loader.visible = false;

        addChild (loaded_element.obj);

        if (loader.contentLoaderInfo)
	    loader.contentLoaderInfo.addEventListener (Event.COMPLETE, loaderLoadCompleteHandler (loaded_element));
        if (loaderComplete (loader))
            doLoaderLoadComplete (loaded_element);

	return loaded_element;
    }

    public function MyChat ()
    {
	stage.scaleMode = StageScaleMode.NO_SCALE;
	stage.align = StageAlign.TOP_LEFT;

        stage_width = stage.stageWidth;
        stage_height = stage.stageHeight;

	conn_closed = false;

	redialing = false;
	new_call = false;
	show_connected_status_msg = true;

	first_reconnect_interval = 1000;
	reconnect_interval = first_reconnect_interval;
	reconnect_timer_active = false;

	my_video_normal_width  = 160;
	my_video_normal_height = 120;
	my_video_fullscreen_width  = 240;
	my_video_fullscreen_height = 180;

	buttons_visible = true;
	hide_buttons_timer = setInterval (hideButtonsTick, 5000);
	hide_buttons_timer_active = true;

	mic_on = true;
	cam_on = true;
	sound_on = true;

	horizontal_mode = false;

	splash = createLoadedElement ("img/splash.png", true /* visible */);

	peer_video = new Video();
	peer_video.width  = 640;
	peer_video.height = 480;
	peer_video.smoothing = true;

	my_video = new Video();
	my_video.width  = my_video_normal_width;
	my_video.height = my_video_normal_height;
	my_video.y = stage_height - my_video.height - 10;
	my_video.x = 10;
	my_video.smoothing = true;

	addChild (peer_video);
	addChild (my_video);

	peer_mic_on = true;
	peer_cam_on = true;

	peer_mic_off_mark = createLoadedElement ("img/peer_mic_off.png", false /* visible */);
	peer_cam_off_mark = createLoadedElement ("img/peer_cam_off.png", false /* visible */);

	my_mic_off_mark = createLoadedElement ("img/my_mic_off.png", false);
	my_cam_off_mark = createLoadedElement ("img/my_cam_off.png", false);

	new_call_button = createLoadedElement ("img/new_call.png", false /* visible */);
	new_call_button.obj.addEventListener (MouseEvent.CLICK, newCall);

	redial_button = createLoadedElement ("img/redial.png", true /* visible */);
	redial_button.obj.addEventListener (MouseEvent.CLICK, redial);

	end_call_button = createLoadedElement ("img/end_call.png", true /* visible */);
	end_call_button.obj.addEventListener (MouseEvent.CLICK, endCall);
	end_call_grey_button = createLoadedElement ("img/end_call_grey.png", true /* visible */);

	roll_button = createLoadedElement ("img/roll.png", true /* visible */);
	roll_button.obj.addEventListener (MouseEvent.CLICK, rollMyVideo);
	unroll_button = createLoadedElement ("img/unroll.png", true /* visible */);
	unroll_button.obj.addEventListener (MouseEvent.CLICK, unrollMyVideo);

	mic_button_on  = createLoadedElement ("img/mic_on.png", true /* visible */);
	mic_button_on.obj.addEventListener (MouseEvent.CLICK, turnMicOff);
	mic_button_off = createLoadedElement ("img/mic_off.png", true /* visible */);
	mic_button_off.obj.addEventListener (MouseEvent.CLICK, turnMicOn);

	cam_button_on  = createLoadedElement ("img/cam_on.png", true /* visible */);
	cam_button_on.obj.addEventListener (MouseEvent.CLICK, turnCamOff);
	cam_button_off = createLoadedElement ("img/cam_off.png", true /* visible */);
	cam_button_off.obj.addEventListener (MouseEvent.CLICK, turnCamOn);

	sound_button_on  = createLoadedElement ("img/sound_on.png", true /* visible */);
	sound_button_on.obj.addEventListener (MouseEvent.CLICK, turnSoundOff);
	sound_button_off = createLoadedElement ("img/sound_off.png", true /* visible */);
	sound_button_off.obj.addEventListener (MouseEvent.CLICK, turnSoundOn);

	fullscreen_button = createLoadedElement ("img/fullscreen.png", true /* visible */);
	fullscreen_button.obj.addEventListener (MouseEvent.CLICK, toggleFullscreen);

	horizontal_button = createLoadedElement ("img/horizontal.png", true /* visible */);
	horizontal_button.obj.addEventListener (MouseEvent.CLICK, toggleHorizontal);

	ExternalInterface.addCallback ("sendChatMessage", sendChatMessage);
	ExternalInterface.addCallback ("connect", connect);

//	uri = "rtmp://172.16.0.17:1935/mychat";
//	uri = "rtmp://10.0.1.3:1935/mychat";
//	uri = "rtmp://192.168.0.32:1935/mychat";
//	uri = "rtmp://192.168.0.146:1935/mychat";
//	uri = "rtmp://127.0.0.1:1935/mychat";
	uri = loaderInfo.parameters ["server_uri"];
	stream_name = "video";

        auth_str = loaderInfo.parameters ["auth"];

	if (true /* Camera.isSupported */) {
	    cam = Camera.getCamera();
	    if (cam) {
		my_video.attachCamera (cam);

//		cam.setMode (320, 240, 15);
		cam.setMode (640, 480, 15);
//		cam.setMode (800, 600, 15);

//		cam.setQuality (65536, 0);
		cam.setQuality (100000, 0);
//		cam.setQuality (10000000, 100);
	    }
	}

	if (true /* Microphone.isSupported */) {
	    mic = Microphone.getEnhancedMicrophone();
            if (mic) {
                mic.setSilenceLevel (0, 2000);
            } else {
                mic = Microphone.getMicrophone();
            }

	    if (mic) {
                mic.codec = SoundCodec.SPEEX;
                mic.setUseEchoSuppression (true);
		mic.setLoopBack (false);
                mic.gain = 50;
            }
	}

	showSplash ();
	showButtons ();

	doResize ();
	stage.addEventListener ("resize",
	    function (event : Event) : void {
		doResize ();
	    }
	);

	stage.addEventListener ("mouseMove", onMouseMove);

	ExternalInterface.call ("flashInitialized");
    }
}

}

internal class LoadedElement
{
    private var visible_allowed : Boolean;
    private var visible : Boolean;

    public var obj : flash.display.Loader;

    public function applyVisible () : void
    {
	obj.visible = visible;
    }

    public function allowVisible () : void
    {
	visible_allowed = true;
	applyVisible ();
    }

    public function setVisible (visible_ : Boolean) : void
    {
	visible = visible_;
	if (visible_allowed)
	    applyVisible ();
    }

    public function LoadedElement (visible_ : Boolean)
    {
	visible = visible_;
	visible_allowed = false;
    }
}

internal class ConnClient
{
    private var mychat : MyChat;

    public function mychat_chat (msg : String) : void
    {
	mychat.addChatMessage (msg);
    }

    public function mychat_mic_on () : void
    {
	mychat.peerMicOn ();
    }

    public function mychat_mic_off () : void
    {
	mychat.peerMicOff ();
    }

    public function mychat_cam_on () : void
    {
	mychat.peerCamOn ();
    }

    public function mychat_cam_off () : void
    {
	mychat.peerCamOff ();
    }

    public function mychat_peer_connected () : void
    {
	mychat.peerConnected ();
    }

    public function mychat_peer_disconnected () : void
    {
	mychat.peerDisconnected ();
    }

    public function mychat_end_call () : void
    {
	mychat.peerEndCall ();
    }

    public function ConnClient (mychat : MyChat)
    {
	this.mychat = mychat;
    }
}

