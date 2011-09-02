package {

import flash.external.ExternalInterface;
import flash.display.Sprite;
import flash.display.StageScaleMode;
import flash.display.StageAlign;
import flash.display.Loader;
import flash.media.Camera;
import flash.media.Video;
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
    private var my_video_normal_width  : Number;
    private var my_video_normal_height : Number;
    private var my_video_fullscreen_width  : Number;
    private var my_video_fullscreen_height : Number;

    private var cam : Camera;

    private var peer_video : Video;
    private var my_video : Video;

    private var conn : NetConnection;

    private var uri : String;
    private var stream_name : String;

    private var buttons_visible : Boolean;

    private var mic_on : Boolean;
    private var cam_on : Boolean;
    private var sound_on : Boolean;

    // If true, then horizontal mode is enabled.
    private var horizontal_mode : Boolean;

    private var roll_button   : LoadedElement;
    private var unroll_button : LoadedElement;
    private var end_call_button   : LoadedElement;
    private var mic_button_on     : LoadedElement;
    private var mic_button_off    : LoadedElement;
    private var cam_button_on     : LoadedElement;
    private var cam_button_off    : LoadedElement;
    private var sound_button_on   : LoadedElement;
    private var sound_button_off  : LoadedElement;
    private var fullscreen_button : LoadedElement;
    private var horizontal_button : LoadedElement;

    private var hide_buttons_timer : uint;

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

    private function doConnect (code : String) : void
    {
	stream_name = code;

	conn = new NetConnection ();
	conn.client = new Client (this);

	conn.objectEncoding = ObjectEncoding.AMF0;
	conn.addEventListener (NetStatusEvent.NET_STATUS, onConnNetStatus);
	conn.connect (uri + '/' + code);
    }

    private function onConnNetStatus (event : NetStatusEvent) : void
    {
	if (event.info.code == "NetConnection.Connect.Success") {
	    var stream : NetStream = new NetStream (conn);
	    stream.bufferTime = 0.1;

	    peer_video.attachNetStream (stream);

	    stream.play (stream_name);

	    stream.publish (stream_name);
	    stream.attachCamera (cam);
	} else
	if (event.info.code == "NetConnection.Connect.Closed") {
	  // TODO
	}
    }

    private function rollMyVideo (event : MouseEvent) : void
    {
	my_video.visible = false;
	showButtons ();
    }

    private function unrollMyVideo (event : MouseEvent) : void
    {
	my_video.visible = true;
	showButtons ();
    }

    private function turnMicOn (event : MouseEvent) : void
    {
	mic_on = true;
	showButtons ();
    }

    private function turnMicOff (event : MouseEvent) : void
    {
	mic_on = false;
	showButtons ();
    }

    private function turnCamOn (event : MouseEvent) : void
    {
	cam_on = true;
	showButtons ();
    }

    private function turnCamOff (event : MouseEvent) : void
    {
	cam_on = false;
	showButtons ();
    }

    private function turnSoundOn (event : MouseEvent) : void
    {
	sound_on = true;
	showButtons ();
    }

    private function turnSoundOff (event : MouseEvent) : void
    {
	sound_on = false;
	showButtons ();
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
	roll_button.obj.x = my_video.x;
	roll_button.obj.y = my_video.y + my_video.height - roll_button.obj.height;

	unroll_button.obj.x = my_video.x;
	unroll_button.obj.y = my_video.y + my_video.height - unroll_button.obj.height;

	end_call_button.obj.x = stage_width - end_call_button.obj.width - 20;
	end_call_button.obj.y = 20;

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
	buttons_visible = false;
	roll_button.setVisible (false);
	unroll_button.setVisible (false);
	end_call_button.setVisible (false);
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

	end_call_button.setVisible (true);

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

	if (!videoShouldBeHorizontal ())
	    horizontal_button.setVisible (true);
	else
	    horizontal_button.setVisible (false);
    }

    private function onMouseMove (event : MouseEvent) : void
    {
	if (hide_buttons_timer) {
	    clearInterval (hide_buttons_timer);
	    hide_buttons_timer = 0;
	}

	hide_buttons_timer = setInterval (hideButtonsTick, 5000);

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

	my_video_normal_width  = 160;
	my_video_normal_height = 120;
	my_video_fullscreen_width  = 240;
	my_video_fullscreen_height = 180;

	buttons_visible = true;
	hide_buttons_timer = setInterval (hideButtonsTick, 5000);

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

	roll_button = createLoadedElement ("img/roll.png", true /* visible */);
	roll_button.obj.addEventListener (MouseEvent.CLICK, rollMyVideo);
	unroll_button = createLoadedElement ("img/unroll.png", true /* visible */);
	unroll_button.obj.addEventListener (MouseEvent.CLICK, unrollMyVideo);

	end_call_button = createLoadedElement ("img/end_call.png", true /* visible */);

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
	ExternalInterface.addCallback ("doConnect", doConnect);

	uri = "rtmp://172.16.0.17:1935/mychat";
	stream_name = "video";

	if (Camera.isSupported) {
	    cam = Camera.getCamera();
	    if (cam) {
		my_video.attachCamera (cam);
		cam.setMode (320, 240, 15);
		cam.setQuality (100000, 0);
	    }
	}

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

internal class Client
{
    private var mychat : MyChat;

    public function mychat_chat (msg : String) : void
    {
	mychat.addChatMessage ('from: ' + msg);
    }

    public function Client (mychat : MyChat)
    {
	this.mychat = mychat;
    }
}

