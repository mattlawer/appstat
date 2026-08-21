CC=clang
FRAMEWORKS= -framework Foundation

PRODUCT=appstat
SRC=appstat.m

CFLAGS=-Wall -g
LDFLAGS=$(FRAMEWORKS)

#iOS
IOS_ARCHS=arm64
SDKMINVERSION=12.0

build-ios-arch=xcrun --sdk iphoneos $(CC) $(SRC) -fobjc-arc $(CFLAGS) $(LDFLAGS) -target $(1)-apple-ios$(SDKMINVERSION) -o $(PRODUCT)_$(1)


.PHONY: all ios clean install

all : appstat clean

ios : appstat_ios clean

appstat : $(SRC)
	$(CC) $(CFLAGS) $(LDFLAGS) $(SRC) -fobjc-arc -o $(PRODUCT)

appstat_ios : $(SRC)
	rm -f $(PRODUCT)_ios
	$(foreach arch,$(IOS_ARCHS),$(call build-ios-arch,$(arch));)
	lipo -create $(addprefix ${PRODUCT}_,${IOS_ARCHS}) -output $(PRODUCT)_ios
	rm -f $(addprefix ${PRODUCT}_,${IOS_ARCHS})

clean :
	rm -rf ./*.o ./*.dSYM

install :
	sudo cp appstat /usr/local/bin/

	