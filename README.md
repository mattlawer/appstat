## appstat
Get AppStore apps reviews, and rankings worldwide for every category.

## Installation
	git clone https://github.com/mattlawer/appstat.git
	cd appstat
	make # 'make ios' to build for iOS 
	make install

## Usage
	Usage : appstat -a <app_id> | -b <bundle_id> | -d <developer> | -s <search> [-r] [-p -m -f] [-g <genre> -c <country> -l <list_size>]
		-s <search> : search an app
		-a <app_id> : the app ID to use
		-b <bundle_id> : the start of the bundle ID to match (top lists only)
		-d <developer> : the developer name
		-c <country_code> : restrict to one country (ex: US), also used for -s
		-g <genre> : genre ID (ex: 6014 for Games)
		-r : list reviews
		-f : search top free
		-p : search top paid
		-m : search top grossing
		-l <list_size> : 1-100 (-p, -f or -m required)
	
	example:
		appstat -s Omnistat -g 6002
		appstat -a 898245825 -r
		appstat -b ch.swift -m -g 6017
