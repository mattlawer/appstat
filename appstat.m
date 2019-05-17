#import <Foundation/Foundation.h>

static NSArray *countries = nil;
static NSOperationQueue *operationQueue = nil;

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

static NSURL* topURL(int cType, NSString *countryCode, int genre, int limit) {
    return [NSURL URLWithString:[NSString stringWithFormat:@"http://itunes.apple.com/%@/rss/top%@applications/limit=%d/%@json", countryCode, cType == 2 ? @"grossing" : cType == 1 ? @"paid" : @"free", limit, genreName(genre) != nil ? [NSString stringWithFormat:@"genre=%d/", genre] : @"genre=6002"]];
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
    printf("Usage : appstat -a <app_id> | -b <bundle_id> | -s <search> [-r] [-p -m -f -g <genre> -l <list_size>]\n");
    printf("\t-s <search> : search an app\n");
    printf("\t-a <app_id> : the app ID to use\n");
    printf("\t-d <developer> : the developer name\n");
    printf("\t-c <country_code> : the country code to use (ex: US)\n");
    printf("\t-r : list reviews\n");
    printf("\t-f : search top free\n");
    printf("\t-m : search top grossing\n");
    printf("\t-p : search top paid\n");
    printf("\t-l <list_size> : 1-100 (-p or -f required)\n");


    printf("\nexample:\n\tappstat -s Omnistat -p\n");
    printf("\tappstat -a 898245825 -r\n");
    exit(0);
}

static id JSONObjectFromURL(NSURL *url, NSError *error);
static NSArray* getEntries(id jsonObject);
static void scanTopApps(NSString *appid, NSString *artist, int cType, int listsize);
static void scanReviews(NSString *appid);
static NSString* searchApp(NSString *query, NSString *country);

int main(int argc, char *const argv[]) {

    @autoreleasepool {

        int listsize = 100; // list size
        int rflag,pflag,fflag=0,mflag= 0;      // show reviews

        NSString *appid = nil;
        NSString *developer = nil;
        NSString *country = nil;
        NSString *searchQuery = nil;

        int c;
        opterr = 0;

        while ((c = getopt (argc, argv, ":a:d:c:g:s:l:rpfhm")) != -1)
            switch (c)
        {
            case 'a':
                appid = [NSString stringWithCString:optarg  encoding:NSUTF8StringEncoding];
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
                listsize = MIN(atoi(optarg),100);
                break;
            case '?':
            default:
                if (isprint (optopt))
                    fprintf (stderr, "Unknown option `-%c'.\n", optopt);
                else
                    fprintf (stderr, "Unknown option character `\\x%x'.\n", optopt);
                return 1;
        }

        if (!appid && !developer) {
            if (!searchQuery) {
                fprintf(stderr, "missing app ID, developer or search query\n");
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

        countries = @[@"AL", @"DZ", @"AO", @"AI", @"AG", @"AR", @"AM", @"AU", @"AT", @"AZ", @"BS", @"BH", @"BB", @"BY", @"BE", @"BZ", @"BJ", @"BM", @"BT", @"BO", @"BW", @"BR", @"VG", @"BN", @"BG", @"BF", @"KH", @"CA", @"CV", @"KY", @"TD", @"CL", @"CN", @"CO", @"CG", @"CR", @"HR", @"CY", @"CZ", @"DK", @"DM", @"DO", @"EC", @"EG", @"SV", @"EE", @"FJ", @"FI", @"FR", @"GM", @"DE", @"GH", @"GR", @"GD", @"GT", @"GW", @"GY", @"HN", @"HK", @"HU", @"IS", @"IN", @"ID", @"IE", @"IL", @"IT", @"JM", @"JP", @"JO", @"KZ", @"KE", @"KR", @"KW", @"KG", @"LA", @"LV", @"LB", @"LR", @"LT", @"LU", @"MO", @"MK", @"MG", @"MW", @"MY", @"ML", @"MT", @"MR", @"MU", @"MX", @"FM", @"MD", @"MN", @"MS", @"MZ", @"NA", @"NP", @"NL", @"NZ", @"NI", @"NE", @"NG", @"NO", @"OM", @"PK", @"PW", @"PA", @"PG", @"PY", @"PE", @"PH", @"PL", @"PT", @"QA", @"RO", @"RU", @"ST", @"SA", @"SN", @"SC", @"SL", @"SG", @"SK", @"SI", @"SB", @"ZA", @"ES", @"LK", @"KN", @"LC", @"VC", @"SR", @"SZ", @"SE", @"CH", @"TW", @"TJ", @"TZ", @"TH", @"TT", @"TN", @"TR", @"TM", @"TC", @"UG", @"GB", @"UA", @"AE", @"UY", @"US", @"UZ", @"VE", @"VN", @"YE", @"ZW"];

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
            scanTopApps(appid, developer, 1, listsize);
            [operationQueue waitUntilAllOperationsAreFinished];
            printf("\n");
        }
        if (mflag) {
            scanTopApps(appid, developer, 2, listsize);
            [operationQueue waitUntilAllOperationsAreFinished];
            printf("\n");
        }
        if (fflag) {
            scanTopApps(appid, developer, 0, listsize);
            [operationQueue waitUntilAllOperationsAreFinished];
            printf("\n");
        }
    }
    return 0;
}

static id JSONObjectFromURL(NSURL *url, NSError *error) {
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];

    __block NSData *blockData = nil;
    @try {
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
        error = blockError;

    } @catch (NSException *exception) {
        NSLog(@"Error %@", exception.description);
    } @finally {
        if (!error && blockData) {
            return [NSJSONSerialization JSONObjectWithData:blockData options:0 error:&error];
        }
        fprintf(stderr, "Unable to load data `%s' (%s).\n", url.absoluteString.UTF8String, error.debugDescription.UTF8String);
        return blockData;
    }
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

static void scanTopApps(NSString *appid, NSString *developer, int cType, int listsize) {

    if (appid) {
        printf("search for appID: \033[34m%s\033[m\nin %d top \033[32m%s\033[m\n", appid.UTF8String, listsize, cType == 2 ? "grossing" : cType == 1 ? "paid" : "free");
    } else if (developer) {
        printf("search for developer: \033[34m%s\033[m\nin %d top \033[32m%s\033[m\n", developer.UTF8String, listsize, cType == 2 ? "grossing" : cType == 1 ? "paid" : "free");
    } else {
        return;
    }

    __block int count=0;
    for (NSString *country in countries) {

        [operationQueue addOperationWithBlock:^{

            NSURL *url = topURL(cType,country,listsize);
            NSError* error = nil;

            NSDictionary *result = JSONObjectFromURL(url, error);

            printf("\r%s [%d/%lu]", country.UTF8String, ++count, [countries count]);
            fflush(stdout);

            if (!error && result) {
                NSArray *entries = getEntries(result);
                for (NSDictionary *entry in entries) {
                    NSString *entryid = entry[@"id"];
                    NSString *title = entry[@"name"];
                    NSString *developerName = entry[@"artistName"];
                    if ((appid && [entryid isEqualToString:appid]) || (developer && [[developerName lowercaseString] rangeOfString:[developer lowercaseString]].location != NSNotFound)) {
                        printf("\r\033[34m%ld\033[m in %s - \033[32m%s\033[m by \033[34m%s\033[m\n", [entries indexOfObject:entry]+1, countryName(country).UTF8String, title.UTF8String, developerName.UTF8String);
                    }
                }

            }else {
                if (error) {
                    printf("\r%s [%d/%lu] \033[31mfailed with %s\033[m\n", country.UTF8String, ++count, [countries count], error.debugDescription.UTF8String);
                } else {
                    printf("\r%s [%d/%lu] \033[31mfailed\033[m\n", country.UTF8String, ++count, [countries count]);
                }
            }
        }];
    }
}

static void scanReviews(NSString *appid) {
    printf("search reviews for appID: %s\n",appid.UTF8String);

    __block int count=0;
    for (NSString *country in countries) {

        [operationQueue addOperationWithBlock:^{

            NSURL *url = reviewsURL(country, appid);
            NSError* error = nil;

            NSDictionary *result = JSONObjectFromURL(url, error);

            printf("\r%s [%d/%lu]", country.UTF8String, ++count, [countries count]);
            fflush(stdout);

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
            }else {
                NSLog(@"ERROR: %@",error.debugDescription);
            }
        }];

    }
}

static NSString* searchApp(NSString *query, NSString *country) {
    NSURL *url = searchURL(country, query);
    NSError* error = nil;

    NSDictionary *result = JSONObjectFromURL(url, error);

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
                int index = 1;
                printf ("Select the app index:");
                scanf("%d",&index);
                if (index > 0 && [entries count] >= index) {
                    return [entries[index-1][@"trackId"] stringValue];
                }
            } while (1);
        }
    }else {
        NSLog(@"ERROR: %@",error.debugDescription);
    }
    return nil;
}


