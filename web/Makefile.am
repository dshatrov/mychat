mychatdir = $(datadir)/moment/mychat

MyChat.swf: MyChat.as
	/opt/flex/bin/mxmlc -headless-server=true -static-link-runtime-shared-libraries=true $^

mychat_DATA = index.tpl	\
	      MyChat.swf

CLEANFILES = MyChat.swf

