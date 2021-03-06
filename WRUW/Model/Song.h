//
//  Song.h
//  WRUW
//
//  Created by Nick Jordan on 11/19/13.
//  Copyright (c) 2013 Nick Jordan. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Song : NSObject <NSCoding>

@property (nonatomic, copy) NSString *artist;
@property (nonatomic, copy) NSString *songName;
@property (nonatomic, copy) NSString *album;
@property (nonatomic, copy) NSString *label;
@property (nonatomic, copy) NSString *imageUrl;

-(BOOL)isEqualToSong:(Song *)song;
-(void)loadImage:(void (^)())succeeded;
-(NSString *)formatForURL:(NSString *)string;

@end
