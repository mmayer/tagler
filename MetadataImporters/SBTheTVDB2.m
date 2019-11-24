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

#define API_KEY @"3498815BE9484A62"

static NSArray<NSString *> *TVDBlanguages;

@implementation SBTheTVDB2

+ (void)initialize
{
}

- (NSArray<SBMetadataResult *> *)searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage
{
    return nil;
}

- (NSArray<SBMetadataResult *> *)searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage seasonNum:(NSString *)aSeasonNum episodeNum:(NSString *)aEpisodeNum
{
    return nil;
}

- (SBMetadataResult *)loadTVMetadata:(SBMetadataResult *)aMetadata language:(NSString *)aLanguage
{
    return nil;
}

+ (NSString *)cleanPeopleList:(NSString *)s
{
    return nil;
}

+ (SBMetadataResult *)metadataForEpisode:(NSDictionary *)aEpisode series:(NSDictionary *)aSeries
{
    return nil;
}

@end
