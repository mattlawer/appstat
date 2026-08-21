#import <Foundation/Foundation.h>

static NSArray *countries = nil;
static NSOperationQueue *operationQueue = nil;
static NSObject *printLock = nil;

static NSString* encodeURLString(NSString* URLString) {
    return [URLString stringByAddingPercentEncodingWithAllowedCharacters:
            [NSCharacterSet URLHostAllowedCharacterSet]];
}

static NSURL* searchURL(NSString *countryCode, NSString *search) {
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/search?term=%@&country=%@&entity=software", encodeURLString(search), countryCode]];
}

/* not used yet
 static NSURL* lookupURL(NSString *appID) {
 return [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/lookup?id=%@", appID]];
 }*/

static NSURL* reviewsURL(NSString *countryCode, NSString *appID) {
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/%@/rss/customerreviews/id=%@/sortBy=mostRecent/json", countryCode, appID]];
}

static NSString* genreName(int genre) {
    NSDictionary *genres = @{@6000: @"Business", @6001: @"Weather", @6002: @"Utilities", @6003: @"Travel", @6004: @"Sports", @6005: @"Social Networking", @6006: @"Reference", @6007: @"Productivity", @6008: @"Photo & Video", @6009: @"News", @6010: @"Navigation", @6011: @"Music", @6012: @"Lifestyle", @6013: @"Health & Fitness", @6014: @"Games", @6015: @"Finance", @6016: @"Entertainment", @6017: @"Education", @6018: @"Books", @6020: @"Medical", @6021: @"Magazines & Newspapers", @6022: @"Catalogs", @6023: @"Food & Drink", @6024: @"Shopping", @6025: @"Stickers", @6026: @"Developer Tools", @6027: @"Graphics & Design"};
    return genres[@(genre)];
}

static NSURL* topURL(int cType, NSString *countryCode, int genre, int limit) {
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/%@/rss/top%@applications/limit=%d/%@json", countryCode, cType == 2 ? @"grossing" : cType == 1 ? @"paid" : @"free", limit, genreName(genre) != nil ? [NSString stringWithFormat:@"genre=%d/", genre] : @""]];
}

static NSString *emojiFromCountry(NSString *countryCode) {
    if (countryCode.length != 2) { return @""; }
    int base = 127397;
    wchar_t bytes[2] = {
        base +[countryCode characterAtIndex:0],
        base +[countryCode characterAtIndex:1]
    };
    return [[NSString alloc] initWithBytes:bytes length:countryCode.length *sizeof(wchar_t) encoding:NSUTF32LittleEndianStringEncoding];
}

static NSString *countryName(NSString *countryCode) {
    return [NSString stringWithFormat:@"%@  %@",emojiFromCountry(countryCode), [[NSLocale currentLocale] displayNameForKey:NSLocaleCountryCode value:countryCode]];
}

static void print_usage(void) {
    printf("Usage : appstat -a <app_id> | -b <bundle_id> | -d <developer> | -s <search> [-r] [-p -m -f] [-g <genre> -c <country> -l <list_size>]\n");
    printf("\t-s <search> : search an app\n");
    printf("\t-a <app_id> : the app ID to use\n");
    printf("\t-b <bundle_id> : the start of the bundle ID to match (top lists only)\n");
    printf("\t-d <developer> : the developer name\n");
    printf("\t-c <country_code> : restrict to one country (ex: US), also used for -s\n");
    printf("\t-r : list reviews\n");
    printf("\t-f : search top free\n");
    printf("\t-m : search top grossing\n");
    printf("\t-p : search top paid\n");
    printf("\t-g <genre> : genre ID (ex: 6014 for Games)\n");
    printf("\t-l <list_size> : 1-100 (-p, -f or -m required)\n");


    printf("\nexample:\n\tappstat -s Omnistat -p\n");
    printf("\tappstat -a 898245825 -r\n");
    exit(0);
}

static id JSONObjectFromURL(NSURL *url, NSError **error);
static NSArray* getEntries(id jsonObject);
static void scanTopApps(NSString *appid, NSString *artist, NSString *bundleid, int cType, int genre, int listsize);
static void scanReviews(NSString *appid);
static NSString* searchApp(NSString *query, NSString *country);

int main(int argc, char *const argv[]) {

    @autoreleasepool {

        int listsize = 100; // list size
        int genre = 0;
        int rflag=0,pflag=0,fflag=0,mflag=0;

        NSString *appid = nil;
        NSString *bundleid = nil;
        NSString *developer = nil;
        NSString *country = nil;
        NSString *searchQuery = nil;

        int c;
        opterr = 0;

        while ((c = getopt (argc, argv, ":a:b:d:c:g:s:l:rpfhm")) != -1)
            switch (c)
        {
            case 'a':
                appid = [NSString stringWithCString:optarg  encoding:NSUTF8StringEncoding];
                break;
            case 'b':
                bundleid = [NSString stringWithCString:optarg  encoding:NSUTF8StringEncoding];
                break;
            case 'd':
                developer = [NSString stringWithCString:optarg  encoding:NSUTF8StringEncoding];
                break;
            case 'c':
                country = [NSString stringWithCString:optarg  encoding:NSUTF8StringEncoding];
                break;
            case 's':
                searchQuery = [NSString stringWithCString:optarg encoding:NSUTF8StringEncoding];
                break;
            case 'g':
                genre = atoi(optarg);
                break;
            case 'r':
                rflag = 1;
                break;
            case 'm':
                mflag = 1;
                break;
            case 'p':
                pflag = 1;
                break;
            case 'f':
                fflag = 1;
                break;
            case 'h':
                print_usage();
                break;
            case 'l':
                listsize = MAX(1,MIN(atoi(optarg),100));
                break;
            case '?':
            default:
                if (isprint (optopt))
                    fprintf (stderr, "Unknown option `-%c'.\n", optopt);
                else
                    fprintf (stderr, "Unknown option character `\\x%x'.\n", optopt);
                return 1;
        }

        if (!appid && !developer && !bundleid) {
            if (!searchQuery) {
                fprintf(stderr, "missing app ID, bundle ID, developer or search query\n");
                print_usage();
            }
            NSString *searchID = searchApp(searchQuery, country ?: @"US");
            if (searchID) {
                appid = searchID;
            } else {
                printf("Could not find app named \"%s\"\n", [searchQuery cStringUsingEncoding:NSUTF8StringEncoding]);
                exit(1);
            }
        }

        countries = @[@"AF", @"AL", @"DZ", @"AO", @"AI", @"AG", @"AR", @"AM", @"AU", @"AT", @"AZ", @"BS", @"BH", @"BB", @"BY", @"BE", @"BZ", @"BJ", @"BM", @"BT", @"BO", @"BA", @"BW", @"BR", @"VG", @"BN", @"BG", @"BF", @"KH", @"CM", @"CA", @"CV", @"KY", @"TD", @"CL", @"CN", @"CO", @"CG", @"CD", @"CR", @"CI", @"HR", @"CY", @"CZ", @"DK", @"DM", @"DO", @"EC", @"EG", @"SV", @"EE", @"FJ", @"FI", @"FR", @"GA", @"GM", @"GE", @"DE", @"GH", @"GR", @"GD", @"GT", @"GW", @"GY", @"HN", @"HK", @"HU", @"IS", @"IN", @"ID", @"IQ", @"IE", @"IL", @"IT", @"JM", @"JP", @"JO", @"KZ", @"KE", @"KR", @"XK", @"KW", @"KG", @"LA", @"LV", @"LB", @"LR", @"LY", @"LT", @"LU", @"MO", @"MK", @"MG", @"MW", @"MY", @"MV", @"ML", @"MT", @"MR", @"MU", @"MX", @"FM", @"MD", @"MN", @"MS", @"ME", @"MA", @"MZ", @"MM", @"NA", @"NR", @"NP", @"NL", @"NZ", @"NI", @"NE", @"NG", @"NO", @"OM", @"PK", @"PW", @"PA", @"PG", @"PY", @"PE", @"PH", @"PL", @"PT", @"QA", @"RO", @"RU", @"RW", @"ST", @"SA", @"SN", @"RS", @"SC", @"SL", @"SG", @"SK", @"SI", @"SB", @"ZA", @"ES", @"LK", @"KN", @"LC", @"VC", @"SR", @"SZ", @"SE", @"CH", @"TW", @"TJ", @"TZ", @"TH", @"TO", @"TT", @"TN", @"TR", @"TM", @"TC", @"UG", @"GB", @"UA", @"AE", @"UY", @"US", @"UZ", @"VU", @"VE", @"VN", @"YE", @"ZM", @"ZW"];
        if (country) {
            countries = @[[country uppercaseString]];
        }

        printLock = [[NSObject alloc] init];
        operationQueue = [[NSOperationQueue alloc] init];
        operationQueue.name = @"Operation Queue";
        operationQueue.maxConcurrentOperationCount = 10;

        if (rflag == 0 && pflag == 0 && fflag == 0  && mflag == 0) {
            fprintf(stderr, "use -f or -p or -m or -r to search in top free/paid/grossing or list reviews\n");
        }

        if (rflag) {
            scanReviews(appid);
            [operationQueue waitUntilAllOperationsAreFinished];
            printf("\n");
        }
        if (pflag) {
            scanTopApps(appid, developer, bundleid, 1, genre, listsize);
            [operationQueue waitUntilAllOperationsAreFinished];
            printf("\n");
        }
        if (mflag) {
            scanTopApps(appid, developer, bundleid, 2, genre, listsize);
            [operationQueue waitUntilAllOperationsAreFinished];
            printf("\n");
        }
        if (fflag) {
            scanTopApps(appid, developer, bundleid, 0, genre, listsize);
            [operationQueue waitUntilAllOperationsAreFinished];
            printf("\n");
        }
    }
    return 0;
}

static id JSONObjectFromURL(NSURL *url, NSError **error) {
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];

    __block NSData *blockData = nil;
    __block NSError *blockError = nil;

    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);

    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable subData, NSURLResponse * _Nullable subResponse, NSError * _Nullable subError) {

        blockData = subData;
        blockError = subError;
        dispatch_group_leave(group);
    }] resume];

    dispatch_group_wait(group,  DISPATCH_TIME_FOREVER);

    id jsonObject = nil;
    if (!blockError && blockData) {
        jsonObject = [NSJSONSerialization JSONObjectWithData:blockData options:0 error:&blockError];
    }
    if (error) {
        *error = blockError;
    }
    return jsonObject;
}

static NSArray* getEntries(id jsonObject) {
    if ([jsonObject[@"feed"][@"results"] isKindOfClass:[NSArray class]]) {
        return jsonObject[@"feed"][@"results"];
    }else if (jsonObject[@"feed"][@"results"]) {
        return @[jsonObject[@"feed"][@"results"]];
    }else if ([jsonObject[@"feed"][@"entry"] isKindOfClass:[NSArray class]]) {
        return jsonObject[@"feed"][@"entry"];
    }else if (jsonObject[@"feed"][@"entry"]) {
        return @[jsonObject[@"feed"][@"entry"]];
    }
    return nil;
}

static void scanTopApps(NSString *appid, NSString *developer, NSString *bundleid, int cType, int genre, int listsize) {

    NSString *genreSuffix = genreName(genre) != nil ? [NSString stringWithFormat:@" %@", genreName(genre)] : @"";
    const char *listName = cType == 2 ? "grossing" : cType == 1 ? "paid" : "free";
    if (appid) {
        printf("search for appID: \033[34m%s\033[m\nin %d top \033[32m%s%s\033[m\n", appid.UTF8String, listsize, listName, genreSuffix.UTF8String);
    } else if (developer) {
        printf("search for developer: \033[34m%s\033[m\nin %d top \033[32m%s%s\033[m\n", developer.UTF8String, listsize, listName, genreSuffix.UTF8String);
    } else if (bundleid) {
        printf("search for bundleID: \033[34m%s\033[m\nin %d top \033[32m%s%s\033[m\n", bundleid.UTF8String, listsize, listName, genreSuffix.UTF8String);
    } else {
        return;
    }

    __block int count=0;
    for (NSString *country in countries) {

        [operationQueue addOperationWithBlock:^{

            NSURL *url = topURL(cType,country,genre,listsize);
            NSError* error = nil;

            NSDictionary *result = JSONObjectFromURL(url, &error);

            @synchronized (printLock) {
                printf("\r%s [%d/%lu]", country.UTF8String, ++count, [countries count]);

                if (!error && result) {
                    NSArray *entries = getEntries(result);
                    for (NSDictionary *entry in entries) {
                        NSString *entryid = entry[@"id"];
                        NSString *title = entry[@"name"];
                        NSString *developerName = entry[@"artistName"];
                        NSString *bundleID = nil;
                        if ([entryid isKindOfClass:[NSDictionary class]]) { // old RSS format (genre feeds)
                            entryid = entry[@"id"][@"attributes"][@"im:id"];
                            bundleID = entry[@"id"][@"attributes"][@"im:bundleId"];
                            title = entry[@"im:name"][@"label"];
                            developerName = entry[@"im:artist"][@"label"];
                        }
                        if ((appid && [entryid isEqualToString:appid])
                            || (developer && developerName && [[developerName lowercaseString] rangeOfString:[developer lowercaseString]].location != NSNotFound)
                            || (bundleid && bundleID && [[bundleID lowercaseString] hasPrefix:[bundleid lowercaseString]])) {
                            printf("\r\033[34m%ld\033[m in %s - \033[32m%s\033[m by \033[34m%s\033[m\n", [entries indexOfObject:entry]+1, countryName(country).UTF8String, title.UTF8String, developerName.UTF8String);
                        }
                    }

                }else {
                    if (error) {
                        printf("\r%s [%d/%lu] \033[31mfailed with %s\033[m\n", country.UTF8String, count, [countries count], error.localizedDescription.UTF8String);
                    } else {
                        printf("\r%s [%d/%lu] \033[31mfailed\033[m\n", country.UTF8String, count, [countries count]);
                    }
                }
                fflush(stdout);
            }
        }];
    }
}

static void scanReviews(NSString *appid) {
    if (!appid) {
        fprintf(stderr, "reviews require an app ID (-a or -s)\n");
        return;
    }
    printf("search reviews for appID: %s\n",appid.UTF8String);

    __block int count=0;
    for (NSString *country in countries) {

        [operationQueue addOperationWithBlock:^{

            NSURL *url = reviewsURL(country, appid);
            NSError* error = nil;

            NSDictionary *result = JSONObjectFromURL(url, &error);

            @synchronized (printLock) {
                printf("\r%s [%d/%lu]", country.UTF8String, ++count, [countries count]);

                if (!error && result) {
                    NSArray *entries = getEntries(result);
                    for (NSDictionary *entry in entries) {
                        NSString *author = entry[@"author"][@"name"][@"label"];
                        NSString *rating = entry[@"im:rating"][@"label"];
                        NSString *title = entry[@"title"][@"label"];
                        NSString *content = entry[@"content"][@"label"];
                        NSString *version = entry[@"im:version"][@"label"];

                        int rating_int = [rating intValue];
                        NSString *stars = @"";
                        for (int i = 0; i<5; i++)
                            stars = [stars stringByAppendingString:(i<rating_int) ? @"★" : @" "];

                        printf("\r%s - \033[33m%s\033[m - %s\n\033[34m%s\033[m - \033[32m%s\033[m\n%s\n", version.UTF8String, stars.UTF8String, countryName(country).UTF8String, author.UTF8String, title.UTF8String, content.UTF8String);
                    }
                }else if (error) {
                    printf("\r%s [%d/%lu] \033[31mfailed with %s\033[m\n", country.UTF8String, count, [countries count], error.localizedDescription.UTF8String);
                }
                fflush(stdout);
            }
        }];

    }
}

static NSString* searchApp(NSString *query, NSString *country) {
    NSURL *url = searchURL(country, query);
    NSError* error = nil;

    NSDictionary *result = JSONObjectFromURL(url, &error);

    if (!error && result) {
        NSArray *entries = result[@"results"];
        if ([entries count] == 1) {
            printf("(\033[34m%s\033[m) \033[32m%s\033[m by \033[34m%s\033[m\n", [[(NSNumber *)entries[0][@"trackId"] stringValue] UTF8String], [(NSString *)entries[0][@"trackCensoredName"] UTF8String], [(NSString *)entries[0][@"sellerName"] UTF8String]);
            return [entries[0][@"trackId"] stringValue];
        }else if ([entries count] > 0) {
            int count = 1;
            for (NSDictionary *entry in entries) {
                printf("%d)\t(\033[34m%s\033[m) \033[32m%s\033[m by \033[34m%s\033[m\n", count++, [[(NSNumber *)entry[@"trackId"] stringValue] UTF8String], [(NSString *)entry[@"trackCensoredName"] UTF8String], [(NSString *)entry[@"sellerName"] UTF8String]);
            }
            do {
                int index = 0;
                printf ("Select the app index:");
                if (scanf("%d",&index) != 1) {
                    int ch;
                    while ((ch = getchar()) != '\n' && ch != EOF); // discard invalid input
                    if (ch == EOF) { return nil; }
                    continue;
                }
                if (index > 0 && [entries count] >= index) {
                    return [entries[index-1][@"trackId"] stringValue];
                }
            } while (1);
        }
    }else {
        fprintf(stderr, "search failed: %s\n", error.localizedDescription.UTF8String ?: "no result");
    }
    return nil;
}


