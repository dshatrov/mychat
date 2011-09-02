mychatdir = $(datadir)/moment/mychat

# Flash movie is not positioned correctly without -default-size option.
MyChat.swf: MyChat.as
	/opt/flex/bin/mxmlc -debug=true -default-size 640 480 $^

mychat_DATA = index.html	\
	      MyChat.swf

CLEANFILES = MyChat.swf

