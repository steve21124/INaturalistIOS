//
//  ExploreSearchCompleteCell.m
//  Explore Prototype
//
//  Created by Alex Shepard on 10/9/14.
//  Copyright (c) 2014 iNaturalist. All rights reserved.
//

#import <FontAwesomeKit/FAKIonIcons.h>

#import "ExploreSearchCompleteCell.h"
#import "UIColor+ExploreColors.h"

@interface ExploreSearchCompleteCell () {
    NSString *_searchText;
}

@end

@implementation ExploreSearchCompleteCell

// designated initializer for UITableViewCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.textLabel.font = [UIFont systemFontOfSize:14.0f];
    }
    return self;
}

- (NSString *)searchText {
    return _searchText;
}

- (void)setSearchText:(NSString *)searchText {
    _searchText = [searchText copy];
    
    NSString *predicate;
    switch (self.searchPredicateType) {
        case ExploreSearchPredicateTypeCritter:
            predicate = @"critters";
            break;
        case ExploreSearchPredicateTypePeople:
            predicate = @"observers";
            break;
        case ExploreSearchPredicateTypeLocation:
            predicate = @"places";
            break;
        case ExploreSearchPredicateTypeProject:
            predicate = @"projects";
            break;
        default:
            break;
    }

    // use an attributed string to make the text vary
    NSString *str = [NSString stringWithFormat:@"Find %@ named '", predicate];
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:str];
    [attr addAttributes:@{ NSFontAttributeName: [UIFont boldSystemFontOfSize:14.0f] }
                  range:[str rangeOfString:predicate]];
    
    NSAttributedString *attr2 = [[NSAttributedString alloc] initWithString:searchText
                                                                attributes:@{ NSFontAttributeName: [UIFont italicSystemFontOfSize:14.0f] }];
    [attr appendAttributedString:attr2];
    
    NSAttributedString *attr3 = [[NSAttributedString alloc] initWithString:@"'" attributes:@{}];
    [attr appendAttributedString:attr3];
    
    //searchTextLabel.attributedText = attr;
    self.textLabel.attributedText = attr;
}

@end
