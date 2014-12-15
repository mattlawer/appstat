CC=gcc
FRAMEWORKS:= -framework Foundation -framework Cocoa
LIBRARIES:= -lobjc

SOURCE=appstat.m

CFLAGS=-Wall -g -v $(SOURCE)
LDFLAGS=$(LIBRARIES) $(FRAMEWORKS)
OUT=-o appstat

all : appstat clean

appstat : $(SOURCE)
	$(CC) $(CFLAGS) $(LDFLAGS) $(OUT) #2>/dev/null

clean :
	rm -rf ./*.dSYM

install :
	sudo cp appstat /usr/local/bin/