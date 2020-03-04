//
//  SBMetadataResult.m
//  Subler
//
//  Created by Damiano Galassi on 17/02/16.
//
//

#import "SBMetadataResult.h"
#import "SBMetadataResultMap.h"
#import <MP42Foundation/MP42/MP42Metadata.h>

// Common Keys
NSString *const SBMetadataResultName = @"{Name}";
NSString *const SBMetadataResultComposer = @"{Composer}";
NSString *const SBMetadataResultGenre = @"{Genre}";
NSString *const SBMetadataResultReleaseDate = @"{Release Date}";
NSString *const SBMetadataResultDescription = @"{Description}";
NSString *const SBMetadataResultLongDescription = @"{Long Description}";
NSString *const SBMetadataResultRating = @"{Rating}";
NSString *const SBMetadataResultStudio = @"{Studio}";
NSString *const SBMetadataResultCast = @"{Cast}";
NSString *const SBMetadataResultDirector = @"{Director}";
NSString *const SBMetadataResultProducers = @"{Producers}";
NSString *const SBMetadataResultScreenwriters = @"{Screenwriters}";
NSString *const SBMetadataResultExecutiveProducer = @"{Executive Producer}";
NSString *const SBMetadataResultCopyright = @"{Copyright}";

// iTunes Keys
NSString *const SBMetadataResultContentID = @"{contentID}";
NSString *const SBMetadataResultArtistID = @"{artistID}";
NSString *const SBMetadataResultPlaylistID = @"{playlistID}";
NSString *const SBMetadataResultITunesCountry = @"{iTunes Country}";
NSString *const SBMetadataResultITunesURL = @"{iTunes URL}";

// TV Show Keys
NSString *const SBMetadataResultSeriesName = @"{Series Name}";
NSString *const SBMetadataResultSeriesDescription = @"{Series Description}";
NSString *const SBMetadataResultTrackNumber = @"{Track #}";
NSString *const SBMetadataResultDiskNumber = @"{Disk #}";
NSString *const SBMetadataResultEpisodeNumber = @"{Episode #}";
NSString *const SBMetadataResultEpisodeID = @"{Episode ID}";
NSString *const SBMetadataResultSeason = @"{Season}";
NSString *const SBMetadataResultNetwork = @"{Network}";

@implementation SBMetadataResult

- (instancetype)init
{
    if (self = [super init]) {
        _tags = [NSMutableDictionary dictionary];
        _artworks = [NSMutableArray array];
    }

    return self;
}

- (instancetype)initWithDict:(NSDictionary *)dict
{
    if (!(self = [super init])) {
        return nil;
    }

    _tags = [dict[@"Tags"] mutableCopy];
    _artworkFullsizeURLs = [SBMetadataResult
                            artworkStringsToURLs:dict[@"Artwork"][@"FullsizeURLs"]];
    _artworkThumbURLs = [SBMetadataResult
                         artworkStringsToURLs:dict[@"Artwork"][@"ThumbURLs"]];
    _artworkProviderNames = [dict[@"Artwork"][@"Providers"] mutableCopy];

    return self;
}

- (instancetype)initFromJSONFile:(NSString *)fileName
{
    NSError *error = nil;
    NSData *contents = [NSData dataWithContentsOfFile:fileName];
    NSDictionary *jsonMeta = [NSJSONSerialization JSONObjectWithData:contents
                                                             options:kNilOptions
                                                               error:&error];
    if (error) {
        return nil;
    }

    return [self initWithDict:jsonMeta];
}

- (NSString *)description
{
    NSArray *keys;
    BOOL isTVShow = (_tags[SBMetadataResultSeriesName] != nil);
    NSMutableString *desc = [NSMutableString string];

    if (isTVShow) {
        keys = [SBMetadataResult tvShowKeys];
    } else {
        keys = [SBMetadataResult movieKeys];
    }

    [desc appendString:@"<\n"];
    [desc appendFormat:@"    isTVShow: %d\n", isTVShow];

    for (NSString *key in keys) {
        [desc appendFormat:@"    %@: %@\n", key, _tags[key]];
    }
    [desc appendString:@">"];

    return desc;
}

+ (NSArray<NSString *> *)movieKeys
{
    return @[SBMetadataResultName,
             SBMetadataResultComposer,
             SBMetadataResultGenre,
             SBMetadataResultReleaseDate,
             SBMetadataResultDescription,
             SBMetadataResultLongDescription,
             SBMetadataResultRating,
             SBMetadataResultStudio,
             SBMetadataResultCast,
             SBMetadataResultDirector,
             SBMetadataResultProducers,
             SBMetadataResultScreenwriters,
             SBMetadataResultExecutiveProducer,
             SBMetadataResultCopyright,
             SBMetadataResultContentID,
             SBMetadataResultITunesCountry];
}

+ (NSArray<NSString *> *)tvShowKeys
{
    return @[SBMetadataResultName,
             SBMetadataResultSeriesName,
             SBMetadataResultComposer,
             SBMetadataResultGenre,
             SBMetadataResultReleaseDate,

             SBMetadataResultTrackNumber,
             SBMetadataResultDiskNumber,
             SBMetadataResultEpisodeNumber,
             SBMetadataResultNetwork,
             SBMetadataResultEpisodeID,
             SBMetadataResultSeason,

             SBMetadataResultDescription,
             SBMetadataResultLongDescription,
             SBMetadataResultSeriesDescription,

             SBMetadataResultRating,
             SBMetadataResultStudio,
             SBMetadataResultCast,
             SBMetadataResultDirector,
             SBMetadataResultProducers,
             SBMetadataResultScreenwriters,
             SBMetadataResultExecutiveProducer,
             SBMetadataResultCopyright,
             SBMetadataResultContentID,
             SBMetadataResultArtistID,
             SBMetadataResultPlaylistID,
             SBMetadataResultITunesCountry];
}

+ (NSArray<NSString *> *)artworkURLsToStrings:(NSArray<NSURL *> *)artworkURL
{
    NSMutableArray *arr = [NSMutableArray array];

    for (NSURL *u in artworkURL) {
        [arr addObject:[u absoluteString]];
    }

    return arr;
}

+ (NSArray<NSURL *> *)artworkStringsToURLs:(NSArray<NSString *> *)artworkString
{
    NSMutableArray *arr = [NSMutableArray array];

    for (NSString *s in artworkString) {
        [arr addObject:[NSURL URLWithString:s]];
    }

    return arr;
}

- (void)merge:(SBMetadataResult *)metadata
{
    [_tags addEntriesFromDictionary:metadata.tags];

    for (MP42Image *artwork in metadata.artworks) {
        [_artworks addObject:artwork];
    }

    _mediaKind = metadata.mediaKind;
    _contentRating = metadata.contentRating;
}

- (void)removeTagForKey:(NSString *)aKey
{
    [_tags removeObjectForKey:aKey];
}

- (void)setTag:(id)value forKey:(NSString *)key
{
    _tags[key] = value;
}

- (id)objectForKeyedSubscript:(NSString *)key
{
    return _tags[key];
}

- (void)setObject:(id)obj forKeyedSubscript:(NSString *)key
{
    if (obj == nil) {
        [self removeTagForKey:key];
    }
    else {
        [self setTag:obj forKey:key];
    }
}

- (NSDictionary *)dictRepresentation
{
    NSMutableDictionary *allArtwork = [NSMutableDictionary dictionary];
    NSMutableDictionary *allMetaData = [NSMutableDictionary dictionary];
    // To serialize to JSON, we can't use NSURL * objects. Convert NSURL *
    // arrays into arrays of NSString *.
    NSArray *artwork = [SBMetadataResult artworkURLsToStrings:_artworkFullsizeURLs];
    NSArray *thumbs = [SBMetadataResult artworkURLsToStrings:_artworkThumbURLs];

    // Create an artwork dictionary containing the three artwork arrays
    [allArtwork setObject:artwork forKey:@"FullsizeURLs"];
    [allArtwork setObject:thumbs forKey:@"ThumbURLs"];
    [allArtwork setObject:_artworkProviderNames forKey:@"Providers"];

    // The top-level dictionary contains tags and artwork underneath
    [allMetaData setObject:_tags forKey:@"Tags"];
    [allMetaData setObject:allArtwork forKey:@"Artwork"];

    return allMetaData;
}

- (int)exportJSONToFile:(NSString *)fileName
{
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:[self dictRepresentation]
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData
                                                 encoding:NSUTF8StringEncoding];

    [jsonString writeToFile:fileName atomically:NO
                   encoding:NSUTF8StringEncoding
                      error:&error];
    [jsonString release];

    return (error) ? (int)error.code : 0;
}

- (MP42Metadata *)metadataUsingMap:(SBMetadataResultMap *)map keepEmptyKeys:(BOOL)keep
{
    MP42Metadata *metadata = [[MP42Metadata alloc] init];

    for (SBMetadataResultMapItem *item in map.items) {
        NSMutableString *result = [NSMutableString string];
        for (NSString *component in item.value) {
            if ([component hasPrefix:@"{"] && [component hasSuffix:@"}"] && component.length > 2) {
                id value = _tags[component];
                if ([value isKindOfClass:[NSString class]] && [value length]) {
                    [result appendString:value];
                }
                else if ([value isKindOfClass:[NSNumber class]]) {
                    [result appendString:[value stringValue]];
                }
            }
            else {
                [result appendString:component];
            }
        }

        if (result.length) {
            [metadata setTag:result forKey:item.key];
        }
        else if (keep) {
            [metadata setTag:result forKey:item.key];
        }
    }

    for (MP42Image *artwork in self.artworks) {
        [metadata.artworks addObject:artwork];
    }

    metadata.mediaKind = self.mediaKind;
    metadata.contentRating = self.contentRating;

    return metadata;
}

@end
