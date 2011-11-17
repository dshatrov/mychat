mychatdir = $(datadir)/moment/mychat

MyChat.swf: MyChat.as
	/opt/flex/bin/mxmlc -debug=true $^
#	/opt/flex/bin/mxmlc -debug=true -default-size 640 480 $^

mychat_DATA = index.tpl	\
	      MyChat.swf

CLEANFILES = MyChat.swf

