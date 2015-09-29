#import <Foundation/Foundation.h>

static NSArray *countries = nil;
static NSOperationQueue *operationQueue = nil;

static NSString *genreName(int genre) {
    switch (genre) {
        case 6000: return @"business";
        case 6001: return @"weather";
        case 6002: return @"utilities";
        case 6003: return @"travel";
        case 6004: return @"sports";
        case 6005: return @"social networking";
        case 6006: return @"reference";
        case 6007: return @"productivity";
        case 6008: return @"photo & video";
        case 6009: return @"news";
        case 6010: return @"navigation";
        case 6011: return @"music";
        case 6012: return @"lifestyle";
        case 6013: return @"health & fitness";
        case 6014: return @"games";
        case 6015: return @"finance";
        case 6016: return @"entertainment";
        case 6017: return @"education";
        case 6018: return @"books";
        case 6019: return @"all";
        case 6020: return @"medical";
        case 6021: return @"newsstand";
        case 6022: return @"catalogs";
        case 6023: return @"food & drink";
        
        // Games
        case 7001: return @"action games";
        case 7002: return @"adventure games";
        case 7003: return @"arcade games";
        case 7004: return @"board games";
        case 7005: return @"card games";
        case 7006: return @"casino games";
        case 7007: return @"dice games";
        case 7008: return @"educational games";
        case 7009: return @"family games";
        case 7010: return @"kids games";
        case 7011: return @"music games";
        case 7012: return @"puzzle games";
        case 7013: return @"racing games";
        case 7014: return @"role playing games";
        case 7015: return @"simulation games";
        case 7016: return @"sports games";
        case 7017: return @"strategy games";
        case 7018: return @"trivia games";
        case 7019: return @"word games";
            
        // Newsstand
        case 13001: return @"newsstand - news & politics";
        case 13002: return @"newsstand - fashion & style";
        case 13003: return @"newsstand - home & garden";
        case 13004: return @"newsstand - outdoors & nature";
        case 13005: return @"newsstand - sports & leisure";
        case 13006: return @"newsstand - automotive";
        case 13007: return @"newsstand - arts & photography";
        case 13008: return @"newsstand - brides & weddings";
        case 13009: return @"newsstand - business & investing";
        case 13010: return @"newsstand - children's magazines";
        case 13011: return @"newsstand - computers & internet";
        case 13012: return @"newsstand - cooking, food & drinks";
        case 13013: return @"newsstand - crafts & hobbies";
        case 13014: return @"newsstand - electronics & audio";
        case 13015: return @"newsstand - entertainment";
        case 13017: return @"newsstand - health, mind & body";
        case 13018: return @"newsstand - history";
        case 13019: return @"newsstand - literary magazines & journals";
        case 13020: return @"newsstand - men's interest";
        case 13021: return @"newsstand - movies & music";
        case 13023: return @"newsstand - parenting & family";
        case 13024: return @"newsstand - pets";
        case 13025: return @"newsstand - professional & trade";
        case 13026: return @"newsstand - regional news";
        case 13027: return @"newsstand - science";
        case 13028: return @"newsstand - teens";
        case 13029: return @"newsstand - travel & regional";
        case 13030: return @"newsstand - women’s interest";

    }
    return nil;
}

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
    return [NSURL URLWithString:[NSString stringWithFormat:@"http://itunes.apple.com/%@/rss/customerreviews/id=%@/sortBy=mostRecent/json", countryCode, appID]];
}

static NSURL* topURL(BOOL paid, NSString *countryCode, int genre, int limit) {
    return [NSURL URLWithString:[NSString stringWithFormat:@"http://itunes.apple.com/%@/rss/top%@applications/limit=%d/%@json", countryCode, paid ? @"paid" : @"free", limit, genreName(genre) != nil ? [NSString stringWithFormat:@"genre=%d/", genre] : @""]];
}

static NSString *countryName(NSString *countryCode) {
	return [[NSLocale currentLocale] displayNameForKey:NSLocaleCountryCode value:countryCode];
}

static void print_usage(void) {
    printf("Usage : appstat [ -a <app_id> | -s <search> ] [-g <genre> -l <list_size> -r -p -f]\n");
    printf("\t-s <search> : search an app\n");
    printf("\t-a <app_id> : the app ID to use\n");
    printf("\t-c <country_code> : the country code to use (ex: US)\n");
    printf("\t-g <genre> : the genre code (ex: 6012)\n");
    printf("\t-r : list reviews\n");
    printf("\t-f : search top free\n");
    printf("\t-p : search top paid\n");
    printf("\t-l <list_size> : 1-200\n");
    
    
    printf("\nexample:\n\tappstat -s Omnistat -g 6002\n");
    printf("\tappstat -a 898245825 -r\n");
	exit(0);
}

static void print_genres(void) {
    for (int g = 6000; g < 6024; g++) {
        printf("%d : %s\n", g, genreName(g).UTF8String);
        if (g == 6014) {
            for (int h = 7001; h < 7020; h++) {
                printf("\t%d : %s\n", h, genreName(h).UTF8String);
            }
        }else if (g == 6021) {
            for (int h = 13001; h < 13031; h++) {
                if (h != 13015) {
                    printf("\t%d : %s\n", h, genreName(h).UTF8String);
                }
            }
        }
    }
	exit(0);
}

static id JSONObjectFromURL(NSURL *url, NSError *error);
static NSArray* getEntries(id jsonObject);
static void scanTopApps(NSString *appid, int genre, BOOL paid, int listsize);
static void scanReviews(NSString *appid);
static NSString* searchApp(NSString *query, NSString *country);

int main(int argc, char *const argv[]) {
    
    @autoreleasepool {
        
        const char *appid = NULL;
        int genre = 6019;   // genre
        int listsize = 200; // list size
        BOOL paid = YES;    // paid
        int rflag = 0;      // show reviews

        NSString *country = nil;
        NSString *searchQuery = nil;
        
        int c;
        opterr = 0;
        
        while ((c = getopt (argc, argv, ":a:c:g:s:rpfhl")) != -1)
            switch (c)
        {
            case 'a':
                appid = optarg;
                break;
            case 'c':
                country = [NSString stringWithCString:optarg  encoding:NSUTF8StringEncoding];
                break;
            case 'g':
                genre = atoi(optarg);
                if (genreName(genre) == nil) {
                    fprintf(stderr, "invalid genre code '%d'\n",genre);
                    print_genres();
                }
                break;
            case 's':
                searchQuery = [NSString stringWithCString:optarg encoding:NSUTF8StringEncoding];
                break;
            case 'r':
                rflag = 1;
                break;
            case 'p':
                paid = YES;
                break;
            case 'f':
                paid = NO;
                break;
            case 'h':
                print_usage();
                break;
            case 'l':
                listsize = MIN(atoi(optarg),200);
                break;
            case '?':
             default:
                if (isprint (optopt))
                    fprintf (stderr, "Unknown option `-%c'.\n", optopt);
                else
                    fprintf (stderr, "Unknown option character `\\x%x'.\n", optopt);
                return 1;
        }
        
        if (appid == NULL) {
            if (searchQuery == nil) {
                fprintf(stderr, "missing app ID or search query\n");
                print_usage();
            }
            NSString *searchID = searchApp(searchQuery, country ?: @"US");
            if (searchID) {
                appid = searchID.UTF8String;
            } else {
                printf("Could not find app named \"%s\"\n", [searchQuery cStringUsingEncoding:NSUTF8StringEncoding]);
                exit(1);
            }
        }
        
        countries = @[@"AL", @"DZ", @"AO", @"AI", @"AG", @"AR", @"AM", @"AU", @"AT", @"AZ", @"BS", @"BH", @"BB", @"BY", @"BE", @"BZ", @"BJ", @"BM", @"BT", @"BO", @"BW", @"BR", @"VG", @"BN", @"BG", @"BF", @"KH", @"CA", @"CV", @"KY", @"TD", @"CL", @"CN", @"CO", @"CG", @"CR", @"HR", @"CY", @"CZ", @"DK", @"DM", @"DO", @"EC", @"EG", @"SV", @"EE", @"FJ", @"FI", @"FR", @"GM", @"DE", @"GH", @"GR", @"GD", @"GT", @"GW", @"GY", @"HN", @"HK", @"HU", @"IS", @"IN", @"ID", @"IE", @"IL", @"IT", @"JM", @"JP", @"JO", @"KZ", @"KE", @"KR", @"KW", @"KG", @"LA", @"LV", @"LB", @"LR", @"LT", @"LU", @"MO", @"MK", @"MG", @"MW", @"MY", @"ML", @"MT", @"MR", @"MU", @"MX", @"FM", @"MD", @"MN", @"MS", @"MZ", @"NA", @"NP", @"NL", @"NZ", @"NI", @"NE", @"NG", @"NO", @"OM", @"PK", @"PW", @"PA", @"PG", @"PY", @"PE", @"PH", @"PL", @"PT", @"QA", @"RO", @"RU", @"ST", @"SA", @"SN", @"SC", @"SL", @"SG", @"SK", @"SI", @"SB", @"ZA", @"ES", @"LK", @"KN", @"LC", @"VC", @"SR", @"SZ", @"SE", @"CH", @"TW", @"TJ", @"TZ", @"TH", @"TT", @"TN", @"TR", @"TM", @"TC", @"UG", @"GB", @"UA", @"AE", @"UY", @"US", @"UZ", @"VE", @"VN", @"YE", @"ZW"];
        
        operationQueue = [[NSOperationQueue alloc] init];
        operationQueue.name = @"Operation Queue";
        operationQueue.maxConcurrentOperationCount = 10;
        
        if (rflag) {
            scanReviews([NSString stringWithFormat:@"%s",appid]);
        }else {
            scanTopApps([NSString stringWithFormat:@"%s",appid], genre, paid, listsize);
        }
        
        [operationQueue waitUntilAllOperationsAreFinished];
    }
    return 0;
}

static id JSONObjectFromURL(NSURL *url, NSError *error) {
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url];
    NSURLResponse* response;
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    [request release];
#pragma GCC diagnostic pop
    if (!data) {
        fprintf(stderr, "Unable to load data `%s'.\n", url.absoluteString.UTF8String);
        return nil;
    }
    
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
}

static NSArray* getEntries(id jsonObject) {
    if ([jsonObject[@"feed"][@"entry"] isKindOfClass:[NSArray class]]) {
        return jsonObject[@"feed"][@"entry"];
    }else if (jsonObject[@"feed"][@"entry"]) {
        return @[jsonObject[@"feed"][@"entry"]];
    }
    return nil;
}

static void scanTopApps(NSString *appid, int genre, BOOL paid, int listsize) {
    NSString *genreStr = genreName(genre);
    printf("search for appID:%s\nin %d top %s%s\n", appid.UTF8String, listsize, paid ? "paid" : "free", genreStr != nil ? [NSString stringWithFormat:@" %s",genreStr.UTF8String].UTF8String : "");
    
    for (NSString *country in countries) {
        
        [operationQueue addOperationWithBlock:^{
            printf("\r%s [%lu/%lu]", country.UTF8String, [countries indexOfObject:country]+1, [countries count]);
            fflush(stdout);
            
            NSURL *url = topURL(paid,country,genre,listsize);
            NSError* error = nil;
            
            NSDictionary *result = JSONObjectFromURL(url, error);
            
            if (!error && result) {
                NSArray *entries = getEntries(result);
                for (NSDictionary *entry in entries) {
                    NSString *entryid = entry[@"id"][@"attributes"][@"im:id"];
                    NSString *title = entry[@"im:name"][@"label"];
                    if ([entryid isEqualToString:appid]) {
                        printf("\r\033[34m%ld\033[m in \033[32m%s\033[m - %s\n", [result[@"feed"][@"entry"] indexOfObject:entry]+1, countryName(country).UTF8String, title.UTF8String);
                    }
                }
                
            }else {
                NSLog(@"ERROR: %@",error.debugDescription);
            }
        }];
        
    }
}

static void scanReviews(NSString *appid) {
    printf("search reviews for appID: %s\n",appid.UTF8String);
    
    for (NSString *country in countries) {
        
        [operationQueue addOperationWithBlock:^{
            printf("\r%s [%lu/%lu]", country.UTF8String, [countries indexOfObject:country]+1, [countries count]);
            fflush(stdout);
            
            NSURL *url = reviewsURL(country, appid);
            NSError* error = nil;
            
            NSDictionary *result = JSONObjectFromURL(url, error);
            
            if (!error && result) {
                NSArray *entries = getEntries(result);
                NSString *bundle = nil;
                for (NSDictionary *entry in entries) {
                    if ([result[@"feed"][@"entry"] indexOfObject:entry] == 0) {
                        bundle = entry[@"im:name"][@"label"];
                        continue;
                    }
                    NSString *author = entry[@"author"][@"name"][@"label"];
                    NSString *rating = entry[@"im:rating"][@"label"];
                    NSString *title = entry[@"title"][@"label"];
                    NSString *content = entry[@"content"][@"label"];
                    NSString *version = entry[@"im:version"][@"label"];
                    
                    int rating_int = [rating intValue];
                    NSString *stars = @"";
                    for (int i = 0; i<5; i++)
                        stars = [stars stringByAppendingString:(i<rating_int) ? @"★" : @" "];
                    
                    printf("\r%s - %s - \033[33m%s\033[m - %s\n\033[34m%s\033[m - \033[32m%s\033[m\n%s\n", bundle.UTF8String, version.UTF8String, stars.UTF8String, countryName(country).UTF8String, author.UTF8String, title.UTF8String, content.UTF8String);
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
        if ([entries count]) {
            printf("found %s by %s\n",[(NSString *)entries[0][@"trackCensoredName"] UTF8String], [(NSString *)entries[0][@"sellerName"] UTF8String]);
            return [entries[0][@"trackId"] stringValue];
        }
    }else {
        NSLog(@"ERROR: %@",error.debugDescription);
    }
    return nil;
}


