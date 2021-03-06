//
//  ShowCell.m
//  WRUW
//
//  Created by Nick Jordan on 1/31/14.
//  Copyright (c) 2014 Nick Jordan. All rights reserved.
//

#import "ShowCell.h"

@implementation ShowCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)configureForShow:(Show *)show
{
    self.showTextLabel.text = show.title;
    self.hostTextLabel.text = show.host;
    
    NSArray *arr = [show.time componentsSeparatedByString:@": "];
    if ([(NSString *)arr[0] length] > 3) {
        NSString *threeCharDay = [arr[0] substringToIndex:3];
        self.timeTextLabel.text = [NSString stringWithFormat:@"%@: %@",threeCharDay,arr[1]];
    } else {
        self.timeTextLabel.text = show.time;
    }
}

@end
