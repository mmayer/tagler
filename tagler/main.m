//
//  main.m
//  tagler
//
//  Created by Markus Mayer on 2/17/16.
//  Copyright © 2016 Markus Mayer. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <unistd.h>

int tagler_main(int argc, char * const argv[])
{
    int c;

    while ((c = getopt(argc, argv, "T:g:i:")) != -1) {
    }
    return 0;
}

int main(int argc, char * const argv[])
{
    int ret;

    @autoreleasepool {
        ret = tagler_main(argc, argv);
    }
    return ret;
}
