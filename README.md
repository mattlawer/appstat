## appstat
Get AppStore apps reviews, and rankings worldwide for every category.

## Installation
	git clone https://github.com/mattlawer/appstat.git
	cd appstat
	make # 'make ios' to build for iOS 
	make install

## Usage
	Usage : appstat -a <app_id> [-g <genre> -l <list_size> -r -p -f]
		-s <search> : search an app
		-a <app_id> : the app ID  to use
		-b <bundle_id> : the start of the bundle ID to use
		-c <country_code> : the country code to use for the search option (ex: US)
		-g <genre> : the genre code (ex: 6012)
		-r : list reviews
		-f : search top free
		-p : search top paid
		-m : search top grossing
		-l <list_size> : 1-200
	
	example:
		appstat -s Omnistat -g 6002
		appstat -a 898245825 -r
		appstat -b ch.swift -m -g 6017


![](http://oi57.tinypic.com/34pdkll.jpg "Example")
