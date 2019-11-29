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

static NSArray<NSString *> *TVDBlanguages;

@implementation SBTheTVDB2

NSString *api_url = API_URL;
NSString *api_key = API_KEY;

NSString *api_token = nil;

+ (void)initialize
{
    if (self != [SBTheTVDB2 class]) {
        return;
    }
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

- (NSArray<SBMetadataResult *> *)searchTVSeries:(NSString *)aSeriesName
                                       language:(NSString *)aLanguage
                                      seasonNum:(NSString *)aSeasonNum
                                     episodeNum:(NSString *)aEpisodeNum
{
    NSString *series_id = [self getSeriesID:aSeriesName];
    NSDictionary *seriesData = [self queryEpisodeForSeries:series_id
                                                withSeason:aSeasonNum
                                               withEpisode:aEpisodeNum];
    NSArray *seriesArtwork = [self getSeriesArtwork:series_id];

    NSLog(@"%@\n", seriesData[@"episodeName"]);
    NSLog(@"%@\n", seriesData[@"overview"]);
    NSLog(@"%@\n", seriesArtwork);

    return nil;
}

- (SBMetadataResult *)loadTVMetadata:(SBMetadataResult *)aMetadata
                            language:(NSString *)aLanguage
{
    NSLog(@"%s\n", __func__);
    return nil;
}

+ (NSString *)cleanPeopleList:(NSString *)s
{
    NSLog(@"%s\n", __func__);
    return nil;
}

+ (SBMetadataResult *)metadataForEpisode:(NSDictionary *)aEpisode series:(NSDictionary *)aSeries
{
    NSLog(@"%s\n", __func__);
    return nil;
}

@end
