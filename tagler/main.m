//
//  main.m
//  tagler
//
//  Created by Markus Mayer on 2/17/16.
//  Copyright © 2016 Markus Mayer. All rights reserved.
//

//#import <Foundation/Foundation.h>

#import <MP42Foundation/MP42Image.h>
#import <MP42Foundation/MP42Metadata.h>
#import <MP42Foundation/MP42Languages.h>

#import <libgen.h>
#import <unistd.h>

int process_file(const char * const fname)
{
    printf("file %s\n", fname);

    return 0;
}

int tagler_main(int argc, char * const argv[])
{
    int ch, i;
    char *errp;
    int tracks = 0;
    int ret = 0;
    int image_number = -1;
    char *genre = NULL;
    const char *prg = basename(argv[0]);

    while ((ch = getopt(argc, argv, "T:hg:i:")) != -1) {
        switch (ch) {
            case 'T':
                tracks = strtol(optarg, &errp, 10);
                if (errp[0] != '\0') {
                    fprintf(stderr, "%s: invalid track number -- %s\n", prg,
                        optarg);
                    return 1;
                }
                break;
            case 'h':
                fprintf(stderr, "usage: %s [-T<tracks>] [-g<genre>] "
                    "[-i<image>] <file> (<file> ...)\n", prg);
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
            default:
                return 1;
        }
    }
    if (argc == optind) {
        fprintf(stderr, "%s: no files specified\n", prg);
        return 1;
    }

    for (i = optind; i < argc; i++) {
        ret = process_file(argv[i]);
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
