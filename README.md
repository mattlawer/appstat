## appstat

	Usage : main -a <app_id> [-g <genre> -l <list_size> -r -p -f]
		-s <search> : search an app
		-a <app_id> : the app ID to use
		-g <genre> : the genre code (ex: 6012)
		-r : list reviews
		-f : search top free
		-p : search top paid
		-l <list_size> : 1-200

	example:
		appstat -s Omnistat -g 6002
		appstat -a 898245825 -r