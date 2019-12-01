//
//  SBTheTVDB2.m
//  tagler
//
//  Created by Markus Mayer on 2019-11-24.
//  Copyright © 2019 Markus Mayer. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <MP42Foundation/MP42/MP42Ratings.h>
#import <MP42Foundation/MP42/MP42Languages.h>

#import "SBTheTVDB2.h"
#import "SBiTunesStore.h"

#define API_URL @"https://api.thetvdb.com"
#define API_KEY @"90195A61A24B686F"

#define BANNER_URL @"http://thetvdb.com/banners/"

static NSArray<NSString *> *TVDBlanguages;

@implementation SBTheTVDB2 {
    NSString *api_token;
}

NSString *api_url = API_URL;
NSString *api_key = API_KEY;
NSString *banner_url = BANNER_URL;

+ (void)initialize
{
    if (self != [SBTheTVDB2 class]) {
        return;
    }
}

+ (NSString *)createList:(NSArray *)source usingField:(NSString *)field separatedBy:(NSString *)sep
{
    NSMutableString *s = [[NSMutableString alloc] init];

    for (NSDictionary *entry in source) {
        if ([s length] > 0) {
            [s appendString:sep];
        }
        [s appendString:entry[field]];
    }

    return s;
}

- (NSDictionary *)makeJsonRequest:(NSURL *)url withMethod:(NSString *)method withParams:(NSDictionary *)params
{
    NSURLResponse *response;
    NSDictionary *resultJson;
    NSData *responseData;
    NSError *error = nil;
    NSData *jsonBodyData;

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];

    request.HTTPMethod = method;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    if (api_token) {
        NSString *authToken = [NSString stringWithFormat:@"Bearer %@", api_token];
        [request setValue:authToken forHTTPHeaderField:@"Authorization"];
    }

    if (params) {
        jsonBodyData = [NSJSONSerialization dataWithJSONObject:params
                                                       options:kNilOptions
                                                         error:&error];
        [request setHTTPBody:jsonBodyData];
    }

    responseData = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&response
                                                     error:&error];
    //[request release];

    if (error != nil) {
        // NSLog(@"connection: error is not nil: %@\n", [error userInfo]);
        return nil;
    }
    resultJson = [NSJSONSerialization JSONObjectWithData:responseData
                                                 options:kNilOptions
                                                   error:&error];
    //[responseData release];

    if (error != nil) {
        //NSLog(@"error is not nil: %@\n", [error userInfo]);
        return nil;
    }

    return resultJson;
}

- (NSDictionary *)makeJsonRequest:(NSURL *)url withMethod:(NSString *)method
{
    return [self makeJsonRequest:url withMethod:method withParams:nil];
}

- (NSArray *)queryDB:(NSURL *)url
{
    NSDictionary *resultJson = [self makeJsonRequest:url withMethod:@"GET"];

    if (!resultJson) {
        return nil;
    }
    if (!resultJson[@"data"]) {
        return nil;
    }

    // Fake an array if it isn't already. We only need this for seriesInfo.
    // This lets us use a common query method for all queries.
    if (![resultJson[@"data"] isKindOfClass:[NSArray class]]) {
        return @[ resultJson[@"data"] ];
    }

    return resultJson[@"data"];
}

- (NSString *)getSeriesID:(NSString *)name
{
    NSString *encodedName = [name stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURL *search_url = [NSURL URLWithString:
                         [NSString stringWithFormat:@"%@/search/series?name=%@",
                          api_url, encodedName]];
    NSArray *ret = [self queryDB:search_url];

    // We know the array entries are dictionaries, so we cast it
    NSDictionary *series = ret[0];

    return series[@"id"];
}

- (NSArray *)getSeriesArtwork:(NSString *)series_id
{
    NSURL *search_url = [NSURL URLWithString:
                         [NSString stringWithFormat:@"%@/series/%@/images/query?keyType=series",
                          api_url, series_id]];

    return [self queryDB:search_url];
}

- (NSDictionary *)getSeriesInfo:(NSString *)series_id
{
    NSURL *search_url = [NSURL URLWithString:
                         [NSString stringWithFormat:@"%@/series/%@",
                          api_url, series_id]];
    NSArray *ret = [self queryDB:search_url];

    return ret[0];
}

- (NSArray *)getSeriesActors:(NSString *)series_id
{
    NSURL *search_url = [NSURL URLWithString:
                         [NSString stringWithFormat:@"%@/series/%@/actors",
                          api_url, series_id]];

    return [self queryDB:search_url];
}

- (NSDictionary *)queryEpisodeForSeries:(NSString *)series_id
                             withSeason:(NSString *)season
                            withEpisode:(NSString *)episode
{
    NSURL *search_url = [NSURL URLWithString:
                         [NSString stringWithFormat:@"%@/series/%@/episodes/query?airedSeason=%@&airedEpisode=%@",
                          api_url, series_id, season, episode]];
    NSArray *ret = [self queryDB:search_url];

    return ret[0];
}


- (SBTheTVDB2 *)login
{
    NSDictionary *jsonBodyDict = @{@"apikey" : api_key};
    NSURL *login_url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/login", api_url]];
    NSDictionary *resultJson = [self makeJsonRequest:login_url withMethod:@"POST" withParams:jsonBodyDict];

    api_token = [resultJson valueForKey:@"token"];

    return self;
}

- (NSArray<SBMetadataResult *> *)searchTVSeries:(NSString *)aSeriesName
                                       xlanguage:(NSString *)aLanguage
{
    NSLog(@"%s\n", __func__);
    return nil;
}

// http://thetvdb.com/api/3498815BE9484A62/series/328724/all/en.xml

- (NSArray<SBMetadataResult *> *)searchTVSeries:(NSString *)aSeriesName
                                       language:(NSString *)aLanguage
                                      seasonNum:(NSString *)aSeasonNum
                                     episodeNum:(NSString *)aEpisodeNum
{
    NSString *series_id = [self getSeriesID:aSeriesName];
    NSDictionary *episodeData = [self queryEpisodeForSeries:series_id
                                                withSeason:aSeasonNum
                                               withEpisode:aEpisodeNum];
    NSArray *seriesArtwork = [self getSeriesArtwork:series_id];
    NSDictionary *seriesInfo = [self getSeriesInfo:series_id];
    NSArray *seriesActors = [self getSeriesActors:series_id];
    SBMetadataResult *meta;

    if (!episodeData)
        return nil;

    meta = [SBTheTVDB2 metadataForEpisode:episodeData
                            series:seriesInfo
                            actors:seriesActors
                           artwork:seriesArtwork];

    return @[ meta ];
}

- (SBMetadataResult *)loadTVMetadata:(SBMetadataResult *)aMetadata
                            language:(NSString *)aLanguage
{
    NSLog(@"%s\n", __func__);
    return aMetadata;
}

+ (NSString *)cleanPeopleList:(NSString *)s
{
    NSLog(@"%s\n", __func__);
    return nil;
}

+ (SBMetadataResult *)metadataForEpisode:(NSDictionary *)aEpisode
                                  series:(NSDictionary *)aSeries
                                  actors:(NSArray *)aActors
                                 artwork:(NSArray *)aArtwork
{
    SBMetadataResult *metadata = [[SBMetadataResult alloc] init];

    metadata.mediaKind = 10; // TV show

    // TV Show
    metadata[@"TheTVDB Series ID"]              = aSeries[@"id"];
    metadata[SBMetadataResultSeriesName]        = aSeries[@"seriesName"];
    metadata[SBMetadataResultSeriesDescription] = aSeries[@"overview"];
    metadata[SBMetadataResultGenre]             = [aSeries[@"genre"] componentsJoinedByString:@", "];

    // Episode
    metadata[SBMetadataResultName]            = aEpisode[@"episodeName"];
    metadata[SBMetadataResultReleaseDate]     = aEpisode[@"firstAired"];
    metadata[SBMetadataResultDescription]     = aEpisode[@"overview"];
    metadata[SBMetadataResultLongDescription] = aEpisode[@"overview"];

    NSString *ratingString = aSeries[@"rating"];
    if (ratingString.length) {
        metadata[SBMetadataResultRating] = [[MP42Ratings defaultManager]
                                            ratingStringForiTunesCountry:@"USA"
                                            media:@"TV" ratingString:ratingString];
    }

    metadata[SBMetadataResultNetwork] = aSeries[@"network"];
    metadata[SBMetadataResultSeason]  = aEpisode[@"airedSeason"];

    NSString *episodeID = [NSString stringWithFormat:@"%d%02d",
                            [aEpisode[@"airedSeason"] intValue],
                            [aEpisode[@"airedEpisodeNumber"] intValue]];

    metadata[SBMetadataResultEpisodeID]     = episodeID;
    metadata[SBMetadataResultEpisodeNumber] = aEpisode[@"airedEpisodeNumber"];
    metadata[SBMetadataResultTrackNumber]   = aEpisode[@"airedEpisodeNumber"];

    metadata[SBMetadataResultDirector]      = [aEpisode[@"directors"] componentsJoinedByString:@", "];
    metadata[SBMetadataResultScreenwriters] = [aEpisode[@"writers"] componentsJoinedByString:@", "];

    NSString *actorList = [SBTheTVDB2 createList:aActors usingField:@"name" separatedBy:@", "];
    metadata[SBMetadataResultCast] = actorList;

    // Artwork
    NSMutableArray *artworkThumbURLs = [NSMutableArray array];
    NSMutableArray *artworkFullsizeURLs = [NSMutableArray array];
    NSMutableArray *artworkProviderNames = [NSMutableArray array];

    if (aEpisode[@"filename"]) {
        NSURL *u = [NSURL URLWithString:[banner_url stringByAppendingString:aEpisode[@"filename"]]];
        [artworkThumbURLs addObject:u];
        [artworkFullsizeURLs addObject:u];
        [artworkProviderNames addObject:@"TheTVDB|episode"];
    }
    metadata.artworkThumbURLs = artworkThumbURLs;
    metadata.artworkFullsizeURLs = artworkFullsizeURLs;
    metadata.artworkProviderNames = artworkProviderNames;

//NSLog(@"series=%@\n", aSeries);
//NSLog(@"episode=%@\n", aEpisode);
//NSLog(@"actors=%@\n", aActors);
//NSLog(@"artwork=%@\n", aArtwork);

//NSLog(@"%@\n", artworkFullsizeURLs);

#if 0
    // TV Show
    metadata[@"TheTVDB Series ID"]              = [aSeries retrieveForPath:@"id.text"];
    metadata[SBMetadataResultSeriesName]        = [aSeries retrieveForPath:@"SeriesName.text"];
    metadata[SBMetadataResultSeriesDescription] = [aSeries retrieveForPath:@"Overview.text"];
    metadata[SBMetadataResultGenre]             = [SBTheTVDB cleanPeopleList:[aSeries retrieveForPath:@"Genre.text"]];

    // Episode
    metadata[SBMetadataResultName]            = [aEpisode retrieveForPath:@"EpisodeName.text"];
    metadata[SBMetadataResultReleaseDate]     = [aEpisode retrieveForPath:@"FirstAired.text"];
    metadata[SBMetadataResultDescription]     = [aEpisode retrieveForPath:@"Overview.text"];
    metadata[SBMetadataResultLongDescription] = [aEpisode retrieveForPath:@"Overview.text"];

    NSString *ratingString = [aSeries retrieveForPath:@"ContentRating.text"];
    if (ratingString.length) {
        metadata[SBMetadataResultRating] = [[MP42Ratings defaultManager] ratingStringForiTunesCountry:@"USA"
                                                                                    media:@"TV"
                                                                             ratingString:ratingString];
    }

    metadata[SBMetadataResultNetwork] = [aSeries retrieveForPath:@"Network.text"];
    metadata[SBMetadataResultSeason]  = [aEpisode retrieveForPath:@"SeasonNumber.text"];

    NSString *episodeID = [NSString stringWithFormat:@"%d%02d",
                            [[aEpisode retrieveForPath:@"SeasonNumber.text"] intValue],
                            [[aEpisode retrieveForPath:@"EpisodeNumber.text"] intValue]];

    metadata[SBMetadataResultEpisodeID]     = episodeID;
    metadata[SBMetadataResultEpisodeNumber] = [aEpisode retrieveForPath:@"EpisodeNumber.text"];
    metadata[SBMetadataResultTrackNumber]   = [aEpisode retrieveForPath:@"EpisodeNumber.text"];

    metadata[SBMetadataResultDirector]      = [SBTheTVDB cleanPeopleList:[aEpisode retrieveForPath:@"Director.text"]];
    metadata[SBMetadataResultScreenwriters] = [SBTheTVDB cleanPeopleList:[aEpisode retrieveForPath:@"Writer.text"]];

    // Cast
    NSString *actors = [SBTheTVDB cleanPeopleList:[aSeries retrieveForPath:@"Actors.text"]];
    NSString *gueststars = [SBTheTVDB cleanPeopleList:[aEpisode retrieveForPath:@"GuestStars.text"]];
    if (actors.length) {
        if (gueststars.length) {
            metadata[SBMetadataResultCast] = [NSString stringWithFormat:@"%@, %@", actors, gueststars];
        }
        else {
            metadata[SBMetadataResultCast] = actors;
        }
    } else {
        if (gueststars.length) {
            metadata[SBMetadataResultCast] = gueststars;
        }
    }

    // Artwork
    NSMutableArray *artworkThumbURLs = [NSMutableArray array];
    NSMutableArray *artworkFullsizeURLs = [NSMutableArray array];
    NSMutableArray *artworkProviderNames = [NSMutableArray array];

    if ([aEpisode retrieveForPath:@"filename.text"]) {
        NSURL *u = [NSURL URLWithString:[NSString stringWithFormat:@"http://thetvdb.com/banners/%@", [aEpisode retrieveForPath:@"filename.text"]]];
        [artworkThumbURLs addObject:u];
        [artworkFullsizeURLs addObject:u];
        [artworkProviderNames addObject:@"TheTVDB|episode"];
    }

    metadata.artworkThumbURLs = artworkThumbURLs;
    metadata.artworkFullsizeURLs = artworkFullsizeURLs;
    metadata.artworkProviderNames = artworkProviderNames;

    // TheTVDB does not provide the following fields normally associated with TV shows in SBMetadataResult:
    // "Copyright", "Comments", "Producers", "Artist"
#endif

    return metadata;
}

@end
