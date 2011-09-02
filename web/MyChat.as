package {

import flash.external.ExternalInterface;
import flash.display.Sprite;
import flash.display.Loader;
import flash.media.Camera;
import flash.media.Video;
import flash.net.NetConnection;
import flash.net.NetStream;
import flash.net.ObjectEncoding;
import flash.net.URLRequest;
import flash.events.Event;
import flash.events.NetStatusEvent;

public class MyChat extends Sprite
{
    private var cam : Camera;

    private var peer_video : Video;
    private var my_video : Video;

    private var conn : NetConnection;

    private var uri : String;
    private var stream_name : String;

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

    private function repositionSplash () : void
    {
        splash.obj.x = (stage_width - splash.obj.width) / 2;
        splash.obj.y = (stage_height - splash.obj.height) / 2;
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
        stage_width = stage.stageWidth;
        stage_height = stage.stageHeight;

	splash = createLoadedElement ("splash.png", true /* visible */);

	ExternalInterface.addCallback ("sendChatMessage", sendChatMessage);
	ExternalInterface.addCallback ("doConnect", doConnect);

	uri = "rtmp://172.16.0.17:1935/mychat";
	stream_name = "video";

	peer_video = new Video();
	peer_video.width  = 640;
	peer_video.height = 480;
	peer_video.smoothing = true;

	my_video = new Video();
	my_video.width  = 160;
	my_video.height = 120;
	my_video.y = peer_video.height - my_video.height - 10;
	my_video.x = 10;
	my_video.smoothing = true;

	addChild (peer_video);
	addChild (my_video);

	if (Camera.isSupported) {
	    cam = Camera.getCamera();
	    if (cam) {
		my_video.attachCamera (cam);
		cam.setMode (320, 240, 15);
		cam.setQuality (100000, 0);
	    }
	}

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

