//
//  main.m
//  tagler
//
//  Created by Markus Mayer on 2016-02-17.
//  Copyright © 2016 Markus Mayer. All rights reserved.
//

@import AppKit;
#import <MP42Foundation/MP42/MP42File.h>
#import <MP42Foundation/MP42/MP42Image.h>
#import <MP42Foundation/MP42/MP42Metadata.h>
#import <MP42Foundation/MP42/MP42Languages.h>
#import <MP42Foundation/MP42/MP42Utilities.h>

#import <MetadataImporters/SBMetadataImporter.h>
#import <MetadataImporters/SBMetadataResultMap.h>

#import <libgen.h>
#import <unistd.h>
#import <utime.h>

#import <sys/stat.h>

#define ALMOST_4GiB 4000000000

const char *prg;

const char *media_kind_list[] = {
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "Movie",
    "TV Show",
};

const char *hd_kind_list[] = {
    "Non-HD",
    "720p",
    "1080p",
};

int verb_printf(int level, int verbose, const char *fmt, ...)
{
    va_list args;
    int ret = 0;

    if (verbose >= level) {
        va_start(args, fmt);
        ret = vprintf(fmt, args);
        va_end(args);
    }
    return ret;
}

MP42File *open_mp42(const char * const fname, NSURL **url)
{
    NSFileManager *filemgr = [[NSFileManager alloc] init];
    NSString *currentPath = [NSString stringWithFormat:@"%@/", [filemgr
        currentDirectoryPath]];
    NSString *fileNameAsURL = [[NSString stringWithFormat:@"file://%@%s",
        (fname[0] == '/') ? @"" : currentPath, fname]
        stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURL *fileURL = [NSURL URLWithString:fileNameAsURL];
    MP42File *mp4File = [[MP42File alloc] initWithURL:fileURL error:NULL];

    if (url) {
        *url = fileURL;
    }
    return mp4File;
}

void close_mp42(const MP42File *mp4)
{
    [mp4 dealloc];
}

void print_metadata(const MP42Metadata *metadata)
{
    printf("mediaKind: %s (%d)\n"
           "hdVideo: %s (%d)\n",
           media_kind_list[metadata.mediaKind],
           metadata.mediaKind,
           hd_kind_list[metadata.hdVideo],
           metadata.hdVideo);
    for (NSString *key in metadata.tagsDict) {
        const char *value;
        id val = [metadata.tagsDict objectForKey:key];

        if ([val isKindOfClass:[NSString class]]) {
            NSString *str = val;
            value = [str UTF8String];
        } else {
            NSString *str = [val stringValue];
            value = [str UTF8String];
        }
        printf("%s: %s\n", [key UTF8String], value);
    }
}

MP42Metadata *read_file(const char * const fname)
{
    MP42File *mp4File = open_mp42(fname, NULL);
    MP42Metadata *metadata;

    if (!mp4File) {
        fprintf(stderr, "%s: couldn't open %s\n", prg, fname);
        return NULL;
    }

    metadata = [mp4File metadata];

    return metadata;
}

int extract_artwork(const char * const fname)
{
    NSString *fileName = [[[NSString stringWithUTF8String:fname]
        lastPathComponent] stringByDeletingPathExtension];
    MP42File *mp4File = open_mp42(fname, NULL);
    int i = 0;
    NSMutableArray<MP42Image *> *artworks;

    if (!mp4File) {
        fprintf(stderr, "%s: couldn't open %s\n", prg, fname);
        return -1;
    }

    artworks = [[mp4File metadata] artworks];
    for (MP42Image *artwork in artworks) {
        NSData *imageData = [[artwork image] TIFFRepresentation];
        NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:imageData];
        NSDictionary *imageProps = [NSDictionary dictionaryWithObject:
            [NSNumber numberWithFloat:9.0] forKey:NSImageCompressionFactor];
        NSString *imageFileName;
        BOOL ret;

        if (i == 0) {
            imageFileName = [NSString stringWithFormat:@"artwork-%@.png",
                fileName];
        } else {
            imageFileName = [NSString stringWithFormat:@"artwork-%03d-%@.png",
                i, fileName];
        }
        imageData = [imageRep representationUsingType:NSPNGFileType
            properties:imageProps];
        ret = [imageData writeToFile:imageFileName atomically:NO];
        if (!ret) {
            fprintf(stderr, "%s: couldn't write %s -- %s\n", prg,
                [imageFileName UTF8String], strerror(errno));
            return -1;
        }
        i++;
    }

    return 0;
}

int write_to_mp4(const char * const fname, SBMetadataResult *m, int image_index,
                 const char *image, BOOL is_movie, BOOL preserve)
{
    SBMetadataResultMap *resultMap;
    NSData *artworkData = nil;
    NSError *error = nil;
    NSFileManager *filemgr = [[NSFileManager alloc] init];
    NSString *currentPath = [NSString stringWithFormat:@"%@/", [filemgr
        currentDirectoryPath]];

    if (is_movie) {
        resultMap = [SBMetadataResultMap movieDefaultMap];
    } else {
        resultMap = [SBMetadataResultMap tvShowDefaultMap];
    }

    if (image) {
        NSString *imageAsURL = [[NSString stringWithFormat:@"file://%@%s",
            (image[0] == '/') ? @"" : currentPath, image]
            stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSURL *imageURL = [NSURL URLWithString:imageAsURL];
        artworkData = [SBMetadataHelper downloadDataFromURL:imageURL
            withCachePolicy:SBReloadIgnoringLocalCacheData];
        if (!artworkData) {
            printf("Couldn't load arwork from %s\n", image);
        }
    } else if (image_index >= 0) {
        NSURL *artworkURL = m.artworkFullsizeURLs[image_index];
        artworkData = [SBMetadataHelper downloadDataFromURL:artworkURL
            withCachePolicy:SBDefaultPolicy];
    } else {
        printf("No artwork found!\n");
    }
    if (artworkData && artworkData.length) {
        MP42Image *artwork = [[MP42Image alloc] initWithData:artworkData
                                                        type:MP42_ART_JPEG];
        if (artwork) {
            [m.artworks addObject:artwork];
        }
    }

    NSMutableDictionary<NSString *, id> *fileAttributes =
        [NSMutableDictionary dictionary];
    MP42Metadata *meta = [m metadataUsingMap:resultMap keepEmptyKeys:NO];
    NSURL *fileURL;
    MP42File *mp4File = open_mp42(fname, &fileURL);
    if (!mp4File) {
        fprintf(stderr, "%s: couldn't open %s\n", prg, fname);
        return -1;
    }

    [mp4File.metadata mergeMetadata:meta];

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

    struct stat st;
    if (preserve) {
        if (stat(fname, &st) < 0) {
            fprintf(stderr, "%s: couldn't stat %s -- %s\n", prg, fname,
                strerror(errno));
            // We don't wan't to restore the timestamp if we couldn't read it.
            preserve = FALSE;
        }
    }

    [mp4File updateMP4FileWithOptions:fileAttributes error:&error];
    if (preserve) {
        struct utimbuf ut;

        ut.actime = st.st_atime;
        ut.modtime = st.st_mtime;
        if (utime(fname, &ut) < 0) {
            fprintf(stderr, "%s: couldn't restore timestamps -- %s\n", prg,
                strerror(errno));
            return -1;
        }
    }

    return 0;
}

SBMetadataResult *read_json(const char * const fname)
{
    NSString *fileName = [NSString stringWithCString:fname
                                            encoding:NSUTF8StringEncoding];
    SBMetadataResult *meta = [[SBMetadataResult alloc] initFromJSONFile:fileName];

    return meta;
}

int process_file(const char * const fname, const char *provider,
    const char *new_genre, int total_tracks, int image_index, const char *image,
    const char *language, const char *track_title, int season, int episode,
    BOOL preserve, int verbose)
{
    SBMetadataResult *m, *firstHit;
    SBMetadataImporter *searcher = nil;
    SBMetadataResultMap *resultMap;
    NSArray<SBMetadataResult *> *result;
    NSString *title = nil;
    NSString *seasonNum = nil;
    NSString *episodeNum = nil;
    NSString *lang = nil;
    NSString *mediaType = nil;
    NSDictionary<NSString *, NSString *> *parsed = nil;
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

    verb_printf(1, verbose, "Media type: %s\n", [mediaType UTF8String]);

    if ([mediaType isEqualToString:@"movie"]) {
        resultMap = [SBMetadataResultMap movieDefaultMap];
        isMovie = YES;
    } else if ([mediaType isEqualToString:@"tv"]) {
        resultMap = [SBMetadataResultMap tvShowDefaultMap];
    } else {
        fprintf(stderr, "%s: unsupported media type \"%s\"\n", prg,
            [mediaType UTF8String]);
        return -1;
    }

    if (provider) {
        verb_printf(1, verbose, "Search povider: %s\n", provider);
        searcher = [SBMetadataImporter importerForProvider:
                    [NSString stringWithCString:provider
                                       encoding:NSUTF8StringEncoding]];
    } else {
        if ([mediaType isEqualToString:@"movie"]) {
            searcher = [SBMetadataImporter importerForProvider:@"iTunes Store"];
        } else if ([mediaType isEqualToString:@"tv"]) {
            searcher = [SBMetadataImporter importerForProvider:@"TheTVDB2"];
            if (!searcher) {
                printf("%s: Falling back to TheTVDB API v1\n", prg);
                searcher = [SBMetadataImporter importerForProvider:@"TheTVDB"];
            }
        }
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
    verb_printf(1, verbose, "Language: %s\n", [lang UTF8String]);

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
    verb_printf(1, verbose, "Title: %s\n", [title UTF8String]);

    if (isMovie) {
        result = [searcher searchMovie:title language:lang];
    } else {
        if (season >= 0) {
            seasonNum = [NSString stringWithFormat:@"%d", season];
        }
        if (episode >= 0) {
            episodeNum = [NSString stringWithFormat:@"%d", episode];
        }
        verb_printf(1, verbose, "Season: %s\n"
            "Episode: %s\n",
            [seasonNum UTF8String], [episodeNum UTF8String]);
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

    if (image_index >= (int)m.artworkFullsizeURLs.count) {
        image_index = (int)m.artworkFullsizeURLs.count - 1;
    }

    if (image_index >= 0) {
        verb_printf(1, verbose, "Image #: %d\n", image_index);
        if (verbose > 1) {
            for (int i = 0; i < m.artworkFullsizeURLs.count; i++) {
                printf("Image URL #%3d: %s\n", i,
                    [[m.artworkFullsizeURLs[i] absoluteString] UTF8String]);
            }
        }
    }

    if (image) {
        verb_printf(1, verbose, "Image: %s\n", image);
    }

    if (!isMovie && total_tracks > 0) {
        NSString *track = [m.tags objectForKey:@"{Track #}"];
        if (track) {
            NSString *trackWithTotal = [NSString stringWithFormat:@"%@/%d",
                track, total_tracks ];
            [m.tags setObject:trackWithTotal forKey:@"{Track #}"];
        }
    }

    if (new_genre) {
        NSString *genre = [m.tags objectForKey:@"{Genre}"];
        if (genre) {
            NSString *newGenre = [[NSString alloc] initWithCString:new_genre
                encoding:NSUTF8StringEncoding];
            [m.tags setObject:newGenre forKey:@"{Genre}"];
        }
    }

    if (isMovie) {
        printf("Processing \"%s\" (%s), released %s...\n",
            [m.tags[@"{Name}"] UTF8String],
            [m.tags[@"{Genre}"] UTF8String],
            [m.tags[@"{Release Date}"] UTF8String]);
    } else {
        printf("Processing \"%s\" (%s)...\n"
               "            S%02dE%02d (ID %s), \"%s\"\n"
               "            Aired %s\n",
            [m.tags[@"{Series Name}"] UTF8String],
            [m.tags[@"{Genre}"] UTF8String],
            [m.tags[@"{Season}"] intValue],
            [m.tags[@"{Episode #}"] intValue],
            [m.tags[@"{Episode ID}"] UTF8String],
            [m.tags[@"{Name}"] UTF8String],
            [m.tags[@"{Release Date}"] UTF8String]);
    }

    return write_to_mp4(fname, m, image_index, image, isMovie, preserve);
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
    int verbose = 0;
    BOOL preserve = FALSE;
    BOOL read_JSON = FALSE;
    BOOL read_mode = FALSE;
    BOOL extract_mode = FALSE;
    char *genre = NULL;
    char *language = NULL;
    char *search_provider = NULL;
    char *title = NULL;
    char *image = NULL;
    char *json_file = NULL;

    prg = basename(argv[0]);
    while ((ch = getopt(argc, argv, "EI:L:PR:T:e:hg:i:p:t:rs:v")) != -1) {
        switch (ch) {
            case 'E':
                extract_mode = TRUE;
                break;
            case 'I':
                image = optarg;
                break;
            case 'L':
                language = optarg;
                break;
            case 'P':
                preserve = TRUE;
                break;
            case 'R':
                read_JSON = TRUE;
                json_file = optarg;
                break;
            case 'T':
                tracks = (int)strtol(optarg, &errp, 10);
                if (errp[0] != '\0') {
                    fprintf(stderr, "%s: invalid track number -- %s\n", prg,
                        optarg);
                    return 1;
                }
                break;
            case 'e':
                episode = (int)strtol(optarg, &errp, 10);
                if (errp[0] != '\0') {
                    fprintf(stderr, "%s: invalid episode number -- %s\n", prg,
                        optarg);
                    return 1;
                }
                break;
            case 'h':
                fprintf(stderr, "usage: %s [<option(s)>] <file(s)>\n", prg);
                fprintf(stderr,
                    "       -E (extract artwork image(s))\n"
                    "       -I<image-file>\n"
                    "       -L<language>\n"
                    "       -P (preserve timestamp)\n"
                    "       -R<file> (read metadata from JSON file)\n"
                    "       -T<total-tracks-per-seasion#>\n"
                    "       -g<genre>\n"
                    "       -i<image#>\n"
                    "       -p<provider>\n"
                    "       -t<title>\n"
                    "       -r (read metadata from MP4 file)\n"
                    "       -s<season#>\n"
                    "       -v[v...] (verbose; more v's for more verbosity)\n"
                    "       -e<episode#>\n");
                return 0;
            case 'g':
                genre = optarg;
                break;
            case 'i':
                image_number = (int)strtol(optarg, &errp, 10);
                if (errp[0] != '\0') {
                    fprintf(stderr, "%s: invalid image number -- %s\n", prg,
                        optarg);
                    return 1;
                }
                break;
            case 'p':
                search_provider = optarg;
                break;
            case 't':
                title = optarg;
                break;
            case 'r':
                read_mode = TRUE;
                break;
            case 's':
                season = (int)strtol(optarg, &errp, 10);
                if (errp[0] != '\0') {
                    fprintf(stderr, "%s: invalid season number -- %s\n", prg,
                        optarg);
                    return 1;
                }
                break;
            case 'v':
                verbose++;
                break;
            default:
                return 1;
        }
    }
    if (argc == optind) {
        fprintf(stderr, "%s: no files specified\n", prg);
        return 1;
    }
    if (image && image_number >= 0) {
        fprintf(stderr, "%s: -i and -I cannot be specified together\n", prg);
        return 1;
    }
    if (read_mode && optind != 2) {
        fprintf(stderr, "%s: -r can't be combined with another option\n", prg);
        return 1;
    }
    if (extract_mode && optind != 2) {
        fprintf(stderr, "%s: -E can't be combined with another option\n", prg);
        return 1;
    }

    for (i = optind; i < argc; i++) {
        if (read_JSON) {
            SBMetadataResult *meta = read_json(json_file);
            if (meta) {
                ret = write_to_mp4(argv[i], meta, image_number, image, FALSE,
                                   preserve);
            } else {
                ret = -1;
            }
        } else if (read_mode) {
            MP42Metadata *m = read_file(argv[i]);
            if (m) {
                print_metadata(m);
            } else {
                ret = -1;
            }
        } else if (extract_mode) {
            ret = extract_artwork(argv[i]);
        } else {
            ret = process_file(argv[i], search_provider, genre, tracks,
                image_number, image, language, title, season, episode, preserve,
                verbose);
        }
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
        if (ret < 0)
            ret = 1;
    }
    return ret;
}
