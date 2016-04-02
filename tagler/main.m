//
//  main.m
//  tagler
//
//  Created by Markus Mayer on 2016-02-17.
//  Copyright © 2016 Markus Mayer. All rights reserved.
//

@import AppKit;
#import <MP42Foundation/MP42File.h>
#import <MP42Foundation/MP42Image.h>
#import <MP42Foundation/MP42Metadata.h>
#import <MP42Foundation/MP42Languages.h>
#import <MP42Foundation/MP42/MP42Utilities.h>

#import <MetadataImporters/SBMetadataImporter.h>

#import <libgen.h>
#import <unistd.h>

#define ALMOST_4GiB 4000000000

const char *prg;

int process_file(const char * const fname, const char *new_genre,
    int total_tracks, int image_index, const char *language,
    const char *track_title, int season, int episode)
{
    SBMetadataResult *m, *firstHit;
    SBMetadataImporter *searcher;
    NSArray<SBMetadataResult *> *result;
    NSError *error = nil;
    NSString *title = nil;
    NSString *seasonNum = nil;
    NSString *episodeNum = nil;
    NSString *lang = nil;
    NSString *mediaType = nil;
    NSDictionary *parsed = nil;
    BOOL isMovie = NO;

    // Skip parsing if title, season and episode are given on the command line.
    if (!track_title || season < 0 || episode < 0) {
        // We want to parse just the file name without the entire path.
        NSString *fileName = [[[NSString alloc] initWithCString:fname
            encoding:NSUTF8StringEncoding] lastPathComponent];
        parsed = [SBMetadataHelper parseFilename:fileName];
        mediaType = parsed[@"type"];
    } else {
        // Since we have a season and an episode, it must be a TV show.
        mediaType = @"tv";
    }

    printf("Media type: %s\n", [mediaType UTF8String]);
    if ([mediaType isEqualToString:@"movie"]) {
        searcher = [SBMetadataImporter importerForProvider:@"iTunes Store"];
        isMovie = YES;
    } else if ([mediaType isEqualToString:@"tv"]) {
        searcher = [SBMetadataImporter importerForProvider:@"TheTVDB"];
    } else {
        fprintf(stderr, "%s: unsupported media type \"%s\"\n", prg,
            [mediaType UTF8String]);
        return -1;
    }

    if (!searcher) {
        fprintf(stderr, "%s: couldn't create searcher\n", prg);
        return -1;
    }

    if (language) {
        lang = [[NSString alloc] initWithCString:language
            encoding:NSUTF8StringEncoding];
    } else {
        lang = (isMovie) ? @"USA (English)" : @"English";
    }

    for (NSString *key in parsed) {
        NSString *value = [parsed objectForKey: key];
        if ([key isEqualToString:@"seriesName"] ||
            [key isEqualToString:@"title"]) {
            title = value;
        } else if ([key isEqualToString:@"seasonNum"]) {
            seasonNum = value;
        } else if ([key isEqualToString:@"episodeNum"]) {
            episodeNum = value;
        }
    }
    if (track_title) {
        title = [[NSString alloc] initWithCString:track_title
            encoding:NSUTF8StringEncoding];
    }

    if (isMovie) {
        result = [searcher searchMovie:title language:lang];
    } else {
        if (season >= 0) {
            seasonNum = [NSString stringWithFormat:@"%d", season];
        }
        if (episode >= 0) {
            episodeNum = [NSString stringWithFormat:@"%d", episode];
        }
        result = [searcher searchTVSeries:title
            language:lang
            seasonNum:seasonNum
            episodeNum:episodeNum];
    }
    if (!result || [result count] < 1) {
        fprintf(stderr, "%s: no search results for %s\n", prg, fname);
        return -1;
    }
    firstHit = [result objectAtIndex:0];
    if (isMovie) {
        m = [searcher loadMovieMetadata:firstHit language:lang];
    } else {
        m = [searcher loadTVMetadata:firstHit language:lang];
    }
    if (!m) {
        fprintf(stderr, "%s: couldn't load metadata for %s\n", prg, fname);
        return -1;
    }

    if (!isMovie && total_tracks > 0) {
        NSString *track = [m.tags objectForKey:@"Track #"];
        if (track) {
            NSString *trackWithTotal = [NSString stringWithFormat:@"%@/%d",
                track, total_tracks ];
            [m.tags setObject:trackWithTotal forKey:@"Track #"];
        }
    }

    if (new_genre) {
        NSString *genre = [m.tags objectForKey:@"Genre"];
        if (genre) {
            NSString *newGenre = [[NSString alloc] initWithCString:new_genre
                encoding:NSUTF8StringEncoding];
            [m.tags setObject:newGenre forKey:@"Genre"];
        }
    }

    if (isMovie) {
        printf("Processing \"%s\" (released %s)...\n",
            [m.tags[@"Name"] UTF8String],
            [m.tags[@"Release Date"] UTF8String]);
    } else {
        printf("Processing %s S%02dE%02d (ID %s), \"%s\" (aired %s)...\n",
            [m.tags[@"TV Show"] UTF8String],
            [m.tags[@"TV Season"] intValue],
            [m.tags[@"TV Episode #"] intValue],
            [m.tags[@"TV Episode ID"] UTF8String],
            [m.tags[@"Name"] UTF8String],
            [m.tags[@"Release Date"] UTF8String]);
    }
    if (image_index >= m.artworkFullsizeURLs.count) {
        image_index = m.artworkFullsizeURLs.count - 1;
    }
    NSFileManager *filemgr = [[NSFileManager alloc] init];
    NSString *currentPath = [NSString stringWithFormat:@"%@/", [filemgr
        currentDirectoryPath]];
    NSString *fileNameAsURL = [[NSString stringWithFormat:@"file://%@%s",
        (fname[0] == '/') ? @"" : currentPath, fname]
        stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURL *fileURL = [NSURL URLWithString:fileNameAsURL];
    MP42File *mp4File = [[MP42File alloc] initWithURL:fileURL];
    NSMutableDictionary<NSString *, id> *fileAttributes = [NSMutableDictionary dictionary];
    NSURL *artworkURL = m.artworkFullsizeURLs[image_index];
    NSData *artworkData = [SBMetadataHelper downloadDataFromURL:artworkURL withCachePolicy:SBDefaultPolicy];
    if (artworkData && artworkData.length) {
        MP42Image *artwork = [[MP42Image alloc] initWithData:artworkData type:MP42_ART_JPEG];
        if (artwork) {
            [m.artworks addObject:artwork];
        }
    }

    if (!mp4File) {
        fprintf(stderr, "%s: couldn't open %s\n", prg, fname);
        return -1;
    }

    [mp4File.metadata mergeMetadata:m.metadata];

    /*
     * This has to come after merging the rest of the meta data. I found no
     * way to set m.metadata.hdVideo, which would have allowed it to be merged
     * like the rest. Even if I assigned a value to it, it stayed 0. So, we
     * set it on the mp4File object directly instead, after merging.
     */
    for (MP42Track *track in mp4File.tracks) {
        if ([track isKindOfClass:[MP42VideoTrack class]]) {
            MP42VideoTrack *videoTrack = (MP42VideoTrack *)track;
            int hdVideo = isHdVideo((uint64_t)videoTrack.trackWidth,
                (uint64_t)videoTrack.trackHeight);
            if (hdVideo) {
                mp4File.metadata[@"HD Video"] = @(hdVideo);
            }
        }
    }

    unsigned long long originalFileSize =
        [[[filemgr attributesOfItemAtPath:[fileURL path] error:nil]
            valueForKey:NSFileSize] unsignedLongLongValue];
    if (originalFileSize > ALMOST_4GiB) {
        [fileAttributes setObject:@YES forKey:MP4264BitData];
    }

    [mp4File updateMP4FileWithOptions:fileAttributes error:&error];
    if (error) {
        return -1;
    }

    return 0;
}

int tagler_main(int argc, char * const argv[])
{
    int ch, i;
    char *errp;
    int tracks = 0;
    int ret = 0;
    int season = -1;
    int episode = -1;
    int image_number = -1;
    char *genre = NULL;
    char *language = NULL;
    char *title = NULL;

    prg = basename(argv[0]);
    while ((ch = getopt(argc, argv, "L:T:e:hg:i:t:s:")) != -1) {
        switch (ch) {
            case 'L':
                language = optarg;
                break;
            case 'T':
                tracks = strtol(optarg, &errp, 10);
                if (errp[0] != '\0') {
                    fprintf(stderr, "%s: invalid track number -- %s\n", prg,
                        optarg);
                    return 1;
                }
                break;
            case 'e':
                episode = strtol(optarg, &errp, 10);
                if (errp[0] != '\0') {
                    fprintf(stderr, "%s: invalid image number -- %s\n", prg,
                        optarg);
                    return 1;
                }
                break;
            case 'h':
                fprintf(stderr, "usage: %s [<option(s)>] <file(s)>\n", prg);
                fprintf(stderr, "       -L<language>\n"
                    "       -T<total-tracks-per-seasion#>\n"
                    "       -g<genre>\n"
                    "       -i<image#>\n"
                    "       -t<title>\n"
                    "       -s<season#>\n"
                    "       -e<episode#>\n");
                return 0;
            case 'g':
                genre = optarg;
                break;
            case 'i':
                image_number = strtol(optarg, &errp, 10);
                if (errp[0] != '\0') {
                    fprintf(stderr, "%s: invalid image number -- %s\n", prg,
                        optarg);
                    return 1;
                }
                break;
            case 't':
                title = optarg;
                break;
            case 's':
                season = strtol(optarg, &errp, 10);
                if (errp[0] != '\0') {
                    fprintf(stderr, "%s: invalid image number -- %s\n", prg,
                        optarg);
                    return 1;
                }
                break;
            default:
                return 1;
        }
    }
    if (argc == optind) {
        fprintf(stderr, "%s: no files specified\n", prg);
        return 1;
    }

    for (i = optind; i < argc; i++) {
        ret = process_file(argv[i], genre, tracks, image_number, language,
            title, season, episode);
        if (ret < 0) {
            break;
        }
    }

    return ret;
}

int main(int argc, char * const argv[])
{
    int ret;

    @autoreleasepool {
        ret = tagler_main(argc, argv);
    }
    return ret;
}
