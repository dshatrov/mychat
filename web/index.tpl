<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html style="height: 100%" xmlns="http://www.w3.org/1999/xhtml">
<head>
  <script type="text/javascript">
    var server_uri = "rtmp://{{ThisRtmpServerAddr}}/mychat";
  </script>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
  <title>Moment Video Server - http://momentvideo.org</title>
<!--  <link rel="icon" type="image/vnd.microsoft.icon" href="favicon.ico"/> -->
  <style type="text/css">
    body {
      height: 100%;
      padding: 0;
      margin: 0;
      font-size: 16px;
      font-family: sans-serif;
    }

    .chat_app {
      display: none;
      position: relative;
      top: 0;
      left: 0;
      width: 100%;
      min-height: 100%;
    }

    .header {
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      margin-top: 10px;

      /* Flash movie gets reloaded in Firefox when display:none is applied.
       * visibility:hidden and right:-99999px is used as a workaround.
       * There's a minor problem with vertical scrollbar appearing earlier
       * than expected because of this. */
      visibility: hidden;
      left: -99999px;
    }

    .body {
      position: absolute;
      top: 490px;
      bottom: 55px;
      left: 0;
      right: 0;
      width: 100%;
    }

    .footer {
      position: absolute;
      bottom: 10px;
      left: 0;
      width: 100%;
      margin-left: auto;
      margin-right: auto;
    }

    .code_input {
      /* Breaks placeholder color in Firefox.
         color: #333333; */
      height: 30px;
      border: 1px solid #cccccc;
      padding-left: 2px;
      padding-right: 2px;
      font-size: 16px;
    }

    .connect_button {
      height: 30px;
      color: white;
      background-color: green;
      border: 0px;
      padding-left: 7px;
      padding-right: 7px;
      font-size: 14px;
      font-weight: bold;
      text-shadow: 1px 1px 0 #004400;
    }

    .connect_button:hover {
      cursor: pointer;
    }

    .flash_div {
      position: relative;
      width: 640px;
      height: 480px;
      margin-left: auto;
      margin-right: auto;
    }

    .chat_frame {
      width: 634px;
      height: 100%;
      border-left: 1px solid #ccccdd;
      border-right: 1px solid #ccccdd;
      padding-left: 2px;
      padding-right: 2px;
      margin-left: auto;
      margin-right: auto;
    }

    .chat_scroll {
      width: 100%;
      height: 100%;
      margin-left: auto;
      margin-right: auto;
      overflow: auto;
    }

    .chat_div {
      padding-bottom: 1.25ex;
      padding-top: 6px;
      font-size: 14px;
      text-align: left;
      word-wrap: break-word;
    }

    .input_div {
      width: 634px;
      background-color: #ffffff;
      border-left: 1px solid #ccccdd;
      border-right: 1px solid #ccccdd;
      border-bottom: 1px solid #ccccdd;
      padding-left: 2px;
      padding-right: 2px;
      padding-bottom: 2px;
      margin-left: auto;
      margin-right: auto;
      text-align: center;
    }

    .chat_input {
      width: 100%;
      height: 30px;
      /* Breaks placeholder color in Firefox.
         color: #333333; */
      outline: 0;
      padding-left: 2px;
      padding-right: 2px;
      padding-top: 1px;
      padding-bottom: 1px;
      margin: 0;
      font-size: 16px;
      font-family: sans-serif;
    }

    .chat_input_blocked {
      border: 0;
      border-right: 0;
    }

    .chat_input_unblocked {
      border: 0;
      border-right: 0;
    }

    .chat_input_wrapper_blocked {
      border: 5px solid #ccccdd;
      border-right: 4px solid #ccccdd;
    }

    .chat_input_wrapper_unblocked {
      border: 5px solid #707088;
      border-right: 4px solid #707088;
    }

    .send_button {
      width: 0px;
      border: 0;
      margin: 0;
      padding-left: 10px;
      padding-right: 10px;
      font-size: 14px;
      font-weight: bold;
      vertical-align: middle;
    }

    .send_button_blocked {
      color: #f8f8ff;
      background-color: #ccccdd;
      text-shadow: 1px 1px 0 #a0a0d0;
    }

    .send_button_unblocked {
      color: white;
      background-color: #707088;
      text-shadow: 1px 1px 0 #000044;
    }

    .send_button_blocked:hover {
      cursor: default;
    }

    .send_button_unblocked:hover {
      cursor: pointer;
    }

    .chat_phrase {
      padding-left: 8px;
      padding-top: 0.5ex;
    }

    .lead_chat_phrase {
      border-top: 1px dotted #a0a0d0;
      padding-left: 8px;
      padding-top: 0.75ex;
      margin-top: 0.75ex;
    }

    .own_chat_phrase {
      color: #707088;
      padding-left: 8px;
      padding-top: 0.5ex;
    }

    .lead_own_chat_phrase {
      color: #707088;
      border-top: 1px dotted #a0a0d0;
      padding-left: 8px;
      padding-top: 0.75ex;
      margin-top: 0.75ex;
    }

    .status_msg {
      color: #a0a0a0;
      padding-left: 8px;
      padding-top: 0.5ex;
      font-style: oblique;
    }

    .lead_status_msg {
      color: #a0a0a0;
      border-top: 1px dotted #a0a0d0;
      padding-left: 8px;
      padding-top: 0.75ex;
      margin-top: 0.75ex;
      font-style: oblique;
    }

    .status_msg_red {
      color: #aa0000;
    }

    .status_msg_green {
      color: #008000;
    }
  </style>
  <script type="text/javascript" src="swfobject.js"></script>
  <script type="text/javascript">
    var flashvars = {
      "enable_debug"    : "{{MyChat_EnableDebug}}",

      "server_uri"      : server_uri,
      "auth"            : "{{MomentAuthTest}}",

      "enable_h264"     : "{{MyChat_EnableH264}}",
      "enable_aec"      : "{{MyChat_EnableAEC}}",

      "cam_set_mode"    : "{{MyChat_CamSetMode}}",
      "cam_width"       : "{{MyChat_CamWidth}}",
      "cam_height"      : "{{MyChat_CamHeight}}",
      "cam_framerate"   : "{{MyChat_CamFramerate}}",

      "cam_set_quality" : "{{MyChat_CamSetQuality}}",
      "cam_bandwidth"   : "{{MyChat_CamBandwidth}}",
      "cam_quality"     : "{{MyChat_CamQuality}}",
    };

    var params = {
      "movie"   : "MyChat.swf",
      "bgcolor" : "#000000",
      "scale"   : "noscale",
      "quality" : "high",
      "allowfullscreen"   : "true",
      "allowscriptaccess" : "always"
    };

    var attributes = {
      "id"    : "MyChat",
      "width" : "100%",
      "height": "100%",
      "align" : "Default"
    };

    swfobject.embedSWF ("MyChat.swf", "MyChat_div", "100%", "100%",
			"9.0.0", false, flashvars, params, attributes);
  </script>
  <script type="text/javascript">
    var strings = new Object;

    var flash_initialized = false;
    var should_connect = false;

    function codeKeyDown (evt)
    {
	if (evt.keyCode == 13)
	    connect ();
    }

    function flashInitialized ()
    {
        flash = document.getElementById ("MyChat");

        flash.str_ConnectingToServer ("{{str_ConnectingToServer}}");
        flash.str_AwaitingPeer       ("{{str_AwaitingPeer}}");
        flash.str_ConnectionError    ("{{str_ConnectionError}}");
        flash.str_Disconnected       ("{{str_Disconnected}}");
        flash.str_Reconnecting       ("{{str_Reconnecting}}");
        flash.str_NewCall            ("{{str_NewCall}}");
        flash.str_SecondCall         ("{{str_SecondCall}}");
        flash.str_CallEnded          ("{{str_CallEnded}}");
        flash.str_PeerConnected      ("{{str_PeerConnected}}");
        flash.str_PeerDisconnected   ("{{str_PeerDisconnected}}");
        flash.str_PeerEndedCall      ("{{str_PeerEndedCall}}");

	flash_initialized = true;
	if (should_connect)
	    doConnect ();
    }

    function connect ()
    {
	document.getElementById ("WelcomeScreen").style.display = "none";

	document.getElementById ("ChatApp").style.display = "block";
	{
	    header = document.getElementById ("Header");
	    header.style.left = "0";
	    header.style.visibility = "visible";
	}

	doConnect ();

	document.getElementById ("ChatInput").focus();

	{
	    chat_scroll = document.getElementById ("ChatScroll");
	    chat_scroll.scrollTop = chat_scroll.scrollHeight;
	}
    }

    function doConnect ()
    {
	should_connect = true;
	if (!flash_initialized)
	    return;

	document ["MyChat"].connect (document.getElementById ("CodeInput").value);
    }

    function newCall ()
    {
	document.getElementById ("ChatApp").style.display = "none";
	{
	    header = document.getElementById ("Header");
	    header.style.left = "-99999px";
	    header.style.visibility = "hidden";
	}

	document.getElementById ("WelcomeScreen").style.display = "block";

	document.getElementById ("CodeInput").focus();
    }
  </script>
</head>
<body onload="document.getElementById('CodeInput').focus()">
  <div id="WelcomeScreen" style="height: 100%; width: 100%">
    <table style="height: 100%; border: 0; margin-left: auto; margin-right: auto" cellpadding="0" cellspacing="0">
      <tr>
        <td style="vertical-align: middle">
	  <table style="border: 0" cellpadding="0" cellspacing="0">
	    <tr>
	      <td style="vertical-align: middle; padding-right: 1ex">
		<span style="color: #808080">{{str_EnterConversationCode}}:&nbsp;</span>
		<span style="color: #333333">
		  <input id="CodeInput" class="code_input" type="text" placeholder="{{str_ConversationCode}}" onkeydown="codeKeyDown(event)"/>
		</span>
	      </td>
	      <td class="connect_button" onclick="connect()">
                {{str_Connect}}
	      </td>
	    </tr>
	  </table>
	</td>
      </tr>
    </table>
  </div>

  <div id="ChatApp" class="chat_app">
    <div style="height: 490px; padding-bottom: 120px; width: 100%"></div>
    <div class="body">
      <div class="chat_frame">
	<div id="ChatScroll" class="chat_scroll">
	  <div id="ChatDiv" class="chat_div">
	  </div>
	</div>
      </div>
    </div>
    <div class="footer">
      <div class="input_div">
	<table style="width: 100%; height: 100%; border: 0" cellpadding="0" cellspacing="0">
	  <tr>
	    <td style="width: 100%; text-align: left; color: #333333">
	    <div id="ChatInputWrapper" style="chat_input_wrapper_blocked">
	      <input id="ChatInput" class="chat_input chat_input_blocked" type="text" placeholder="{{str_TypeMessageHere}}" onkeydown="chatKeyDown(event)"/>
	      </div>
	    </td>
	    <td id="SendButton" tabindex="0" class="send_button send_button_blocked" style="vertical-align: middle" onclick="sendButtonClick()" onkeydown="sendKeyDown(event)">
              {{str_Send}}
	    </td>
	  </tr>
	</table>
      </div>
    </div>
  </div>

  <!-- Header goes after ChatApp for proper Z order in Chrome -->
  <div id="Header" class="header">

    <div class="flash_div">
      <div id="MyChat_div">
	<a href="http://adobe.com/go/getflashplayer">Get Adobe Flash player</a>
      </div>
    </div>

      <!-- wmode="direct" doesn't work -->
<!-- STATIC EMBEDDING
    <div class="flash_div">
      <object classid="clsid:d27cdb6e-ae6d-11cf-96b8-444553540000"
	  width="100%"
	  height="100%"
	  id="MyChat"
	  align="Default">
	<param name="movie" value="MyChat.swf"/>
	<param name="bgcolor" value="#000000"/>
	<param name="scale" value="noscale"/>
	<param name="quality" value="high"/>
	<param name="allowfullscreen" value="true"/>
	<param name="allowscriptaccess" value="always"/>
	<embed src="MyChat.swf"
	    name="MyChat"
	    align="Default"
	    width="100%"
	    height="100%"
	    bgcolor="#000000"
	    scale="noscale"
	    quality="high"
	    allowfullscreen="true"
	    allowscriptaccess="always"
	    type="application/x-shockwave-flash"
	    pluginspage="http://www.adobe.com/shockwave/download/index.cgi?P1_Prod_Version=ShockwaveFlash"/>
      </object>
    </div>
-->

  </div>

  <script type="text/javascript">
/*    flash       = document ["MyChat"]; */
    chat_input  = document.getElementById ("ChatInput");
    chat_scroll = document.getElementById ("ChatScroll");
    chat_div    = document.getElementById ("ChatDiv");

    got_prv_msg = false;
    prv_phrase_is_own = false;
    prv_msg_is_status = false;

    chat_blocked = true;

    function doAddChatMessage (msg, is_own, is_status, color)
    {
        var scroll_to_bottom = (chat_scroll.scrollTop + chat_scroll.clientHeight >= chat_scroll.scrollHeight);

	var msg_div = document.createElement ('div');

	if (is_status) {
	    if (prv_msg_is_status || !got_prv_msg) {
		msg_div.className = "status_msg";
	    } else {
		msg_div.className = "lead_status_msg";
	    }
	    prv_msg_is_status = true;
	} else {
	    if (is_own) {
		if (got_prv_msg) {
		    if (prv_phrase_is_own && !prv_msg_is_status)
			msg_div.className = "own_chat_phrase";
		    else
			msg_div.className = "lead_own_chat_phrase";
		} else {
		    msg_div.className = "own_chat_phrase";
		}

		prv_phrase_is_own = true;
	    } else {
		if (got_prv_msg) {
		    if (!prv_phrase_is_own && !prv_msg_is_status)
			msg_div.className = "chat_phrase";
		    else
			msg_div.className = "lead_chat_phrase";
		} else {
		    msg_div.className = "chat_phrase";
		}

		prv_phrase_is_own = false;
	    }
	    prv_msg_is_status = false;
	}
	got_prv_msg = true;

	if (color == "red") {
	    msg_div.className += " status_msg_red";
	} else
	if (color == "green") {
	    msg_div.className += " status_msg_green";
	}

	var p_tag = document.createElement ('span');
	var msg_text = document.createTextNode (msg);
	p_tag.appendChild (msg_text);
	msg_div.appendChild (p_tag);
	chat_div.appendChild (msg_div);

	if (scroll_to_bottom)
	    chat_scroll.scrollTop = chat_scroll.scrollHeight;
    }

    function addChatMessage (msg)
    {
	doAddChatMessage (msg, false /* is_own */, false /* is_status */);
    }

    function addStatusMessage (msg)
    {
	doAddChatMessage (msg, false /* is_own */, true /* is_status */, "" /* color */);
    }

    function addRedStatusMessage (msg)
    {
	doAddChatMessage (msg, false /* is_own */, true /* is_status */, "red" /* color */);
    }

    function addGreenStatusMessage (msg)
    {
	doAddChatMessage (msg, false /* is_own */, true /* is_status */, "green" /* color */);
    }

    function sendChatMessage ()
    {
	if (chat_blocked)
	    return;

	msg = chat_input.value;
	chat_input.value = "";

	doAddChatMessage (msg, true /* is_own */, false /* is_status */);
	flash.sendChatMessage (msg);
    }

    function blockChat ()
    {
	chat_blocked = true;
	document.getElementById ("ChatInputWrapper").className = "chat_input_wrapper_blocked";
	document.getElementById ("ChatInput").className = "chat_input chat_input_blocked";
	document.getElementById ("SendButton").className = "send_button send_button_blocked";
    }

    function unblockChat ()
    {
	chat_blocked = false;
	document.getElementById ("ChatInputWrapper").className = "chat_input_wrapper_unblocked";
	document.getElementById ("ChatInput").className = "chat_input chat_input_unblocked";
	document.getElementById ("SendButton").className = "send_button send_button_unblocked";
    }

    function sendButtonClick ()
    {
	sendChatMessage ();
    }

    function chatKeyDown (evt)
    {
	if (evt.keyCode == 13)
	    sendChatMessage ();
    }

    function sendKeyDown (evt)
    {
	if (evt.keyCode == 13 /* Enter */ || evt.keyCode == 32 /* Spacebar */)
	    sendChatMessage ();
    }
  </script>
</body>
</html>

