//
//  ShowsTableViewController.m
//  WRUW
//
//  Created by Nick Jordan on 11/15/13.
//  Copyright (c) 2013 Nick Jordan. All rights reserved.
//

#import "ShowsTableViewController.h"

#import "TFHpple.h"
#import "Show.h"
#import "DisplayViewController.h"
#import "AFHTTPRequestOperationManager.h"
#import "UIColor+WruwColors.h"
#import "WRUWModule-Swift.h"

@interface ShowsTableViewController () {
    NSMutableArray *_objects;
    NSArray *_originalObjects;
    UIActivityIndicatorView *spinner;
    NSArray *sectionTitles;
    NSArray *sectionIndexTitles;
    NSMutableDictionary *programs;
}
@property (nonatomic, strong) ArrayDataSource *showsArrayDataSource;

@end

@implementation ShowsTableViewController

@synthesize dayOfWeek;

-(void) prepareForSegue:(UIStoryboardSegue *)segue sender:(NSIndexPath *)indexPath{
    
    if ([segue.identifier isEqualToString:@"showDisplaySegue"]) {
        DisplayViewController *dvc = [segue destinationViewController];
        
        Show *item = [self showForIndexPath:indexPath];
        
        [dvc setCurrentShow:item];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    sectionTitles = @[@"Sunday",@"Monday",@"Tuesday",@"Wednesday",@"Thursday",@"Friday",@"Saturday"];
    sectionIndexTitles = @[@"Su", @"Mo", @"Tu", @"We", @"Th", @"Fr", @"Sa"];
    self.tableView.sectionIndexColor = [UIColor wruwColor];
    self.tableView.sectionIndexBackgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    
    spinner = [[UIActivityIndicatorView alloc] init];
    spinner.center = CGPointMake(super.view.frame.size.width / 2.0, super.view.frame.size.height / 2.0);
    [spinner setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleGray];
    spinner.color = [UIColor wruwColor];
    [self.view addSubview:spinner];
    
    [spinner startAnimating];
    
    dispatch_queue_t myQueue = dispatch_queue_create("org.wruw.app", NULL);
    
    dispatch_async(myQueue, ^{ [self loadShows]; });

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.dimsBackgroundDuringPresentation = NO;
    self.searchController.searchBar.scopeButtonTitles = @[];
    self.searchController.searchBar.delegate = self;
    [self.searchController.searchBar setPlaceholder:@"Search by program, host, or genre"];
    
    self.tableView.tableHeaderView = self.searchController.searchBar;
    self.definesPresentationContext = YES;
    
    [self.tableView registerNib:[UINib nibWithNibName:@"ShowCell" bundle:nil ] forCellReuseIdentifier:@"ShowCell"];
    
    self.tableView.dataSource = self;
    programs = [[NSMutableDictionary alloc] init];
    
    self.extendedLayoutIncludesOpaqueBars = YES;
    self.automaticallyAdjustsScrollViewInsets = YES;
    self.navigationController.navigationBar.translucent = NO;
    self.searchController.automaticallyAdjustsScrollViewInsets = NO;
}

#pragma mark - Helper methods

-(void)loadShows {
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.responseSerializer = [AFCompoundResponseSerializer serializer];
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObject:@"text/html"];
    NSDictionary *parameters;
    if (dayOfWeek > 0) {
        parameters = @{@"filt-day": [NSString stringWithFormat:@"%d", dayOfWeek]};
    } else {
        parameters = @{@"filt-day": @"all"};
    }
    
    [manager POST:@"http://www.wruw.org/shows-schedule" parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        TFHpple *showsParser = [TFHpple hppleWithHTMLData:responseObject];
        
        // 3
        NSString *showsXpathQueryString = @"//*[@id='main']/div/table[2]/tbody/tr";
        NSArray *showsNodes = [showsParser searchWithXPathQuery:showsXpathQueryString];
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        
        // 4
        NSMutableArray *newShows = [[NSMutableArray alloc] initWithCapacity:0];
        for (TFHppleElement *element in showsNodes) {
            // 5
            Show *show = [[Show alloc] init];
            [newShows addObject:show];
            
            NSArray *elementInformation = [element childrenWithTagName:@"td"];
            
            TFHppleElement *showInfo = elementInformation[0];
            
            // 6
            show.title = [[[showInfo firstChildWithTagName:@"a"] firstChild] content];
            
            NSMutableString *host = [[NSMutableString alloc] initWithString:@""];
            [[elementInformation[1] childrenWithTagName:@"a"] enumerateObjectsUsingBlock:^(TFHppleElement *obj, NSUInteger idx, BOOL *stop) {
                (idx == 0) ? : [host appendString:@", "];
                [host appendString:obj.text];
            }];
            show.host = host;
            
            NSMutableString *genre = [[NSMutableString alloc] initWithString:@""];
            [[elementInformation[2] childrenWithTagName:@"a"] enumerateObjectsUsingBlock:^(TFHppleElement *obj, NSUInteger idx, BOOL *stop) {
                (idx == 0) ? : [genre appendString:@", "];
                [genre appendString:obj.text];
            }];
            show.genre = genre;
            
            show.time = [[elementInformation[3] firstChild] content];
            NSString *abbrWeekday = [[show.time componentsSeparatedByString:@":"] objectAtIndex:0];
            [dateFormatter setDateFormat:@"EEE"];
            NSDate *weekday =[dateFormatter dateFromString:abbrWeekday];
            [dateFormatter setDateFormat:@"EEEE"];
            show.day = [dateFormatter stringFromDate:weekday];
            
            // 7
            show.url = [[showInfo firstChildWithTagName:@"a"] objectForKey:@"href"];
        }
        
        // 8
        _originalObjects = [NSArray arrayWithArray:newShows];
        [self resetObjects];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [spinner stopAnimating];
            [self.tableView reloadData];
        });
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
    }];
}

- (void)resetObjects {
    if (dayOfWeek > 0) {
        NSString *weekday = [sectionTitles objectAtIndex:dayOfWeek - 1];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K = %@", @"day", weekday];
        
        NSArray *matches = [_originalObjects filteredArrayUsingPredicate:predicate];
        _originalObjects = [NSMutableArray arrayWithArray:matches];
    }
    
    _objects = [NSMutableArray arrayWithArray:_originalObjects];
}

- (Show *)showForIndexPath:(NSIndexPath *)indexPath {
    Show *item;
    if (programs.count > 0) {
        NSString *weekday = [sectionTitles objectAtIndex:indexPath.section];
        NSArray *sectionPrograms = [programs objectForKey:weekday];
        item = [sectionPrograms objectAtIndex:indexPath.row];
    } else {
        item = [_objects objectAtIndex:indexPath.row];
    }
    
    return item;
}

#pragma mark - Search Results Updating delegate

- (void)searchForText:(NSString *)searchText
{
    [_objects removeAllObjects];
    if (searchText.length > 0) {
        
        NSArray *keys = @[@"title", @"host", @"genre"];
        
        for (NSString *key in keys) {
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K CONTAINS[c] %@", key, searchText];
            
            NSArray *matches = [_originalObjects filteredArrayUsingPredicate:predicate];
            [_objects addObjectsFromArray:matches];
        }
    } else {
        [self resetObjects];
    }
    
    [self.tableView reloadData];

}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
    NSString *searchString = searchController.searchBar.text;
    [self searchForText:searchString];
    [self.tableView reloadData];
}

#pragma mark - Search bar delegate

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope
{
    [self updateSearchResultsForSearchController:self.searchController];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
}

#pragma mark - Table view delegate 

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self performSegueWithIdentifier:@"showDisplaySegue" sender:indexPath];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if ([self tableView:tableView numberOfRowsInSection:section]) {
        return 60.0;
    } else {
        return 0.0;
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    // initialization
    float width;
    NSString *headerText;
    if (dayOfWeek) {
        headerText = sectionTitles[dayOfWeek - 1];
        width = tableView.frame.size.width;
    } else {
        headerText = sectionTitles[section];
        width = tableView.frame.size.width -18;
    }
    
    // Initilize header view
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 60)];
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path,NULL,0.0,0.0);
    CGPathAddLineToPoint(path, NULL, width, 0);
    CGPathAddLineToPoint(path, NULL, width, 60);
    CGPathAddLineToPoint(path, NULL, width/2 + 12.5, 60);
    CGPathAddLineToPoint(path, NULL, width/2, 48);
    CGPathAddLineToPoint(path, NULL, width/2 - 12.5, 60);
    CGPathAddLineToPoint(path, NULL, 0, 60);
    CGPathAddLineToPoint(path, NULL, 0, 0);
    
    CAShapeLayer *shapeLayer = [CAShapeLayer layer];
    [shapeLayer setPath:path];
    [shapeLayer setFillColor:[[[UIColor wruwColor] colorWithAlphaComponent:0.95] CGColor]];
    [shapeLayer setBounds:CGRectMake(0.0f, 0.0f, width, 60)];
    [shapeLayer setAnchorPoint:CGPointMake(0.0f, 0.0f)];
    [shapeLayer setPosition:CGPointMake(0.0f, 0.0f)];
    [[view layer] addSublayer:shapeLayer];

    // Make label for day of week
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10, 5, width, 18)];
    [label setFont:[UIFont fontWithName:@"GillSans-SemiBold" size:18.0]];
    [label setText:headerText];
    [label setTextColor:[UIColor whiteColor]];
    [label setTextAlignment:NSTextAlignmentCenter];
    
    // add subviews
    [view addSubview:label];
    label.center = view.center;
    
    return view;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (dayOfWeek == 0) {
        return [sectionTitles count];
    } else {
        return 1;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (dayOfWeek == 0) {
        return [sectionTitles objectAtIndex:section];
    } else {
        return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (dayOfWeek == 0) {
        NSString *weekday = [sectionTitles objectAtIndex:section];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K = %@", @"day", weekday];
        
        NSArray *matches = [_objects filteredArrayUsingPredicate:predicate];
        (matches) ? [programs setObject:matches forKey:weekday] : nil;
        return [matches count];
    } else {
        return _objects.count;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ShowCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ShowCell"];
    if (!cell) {
        [tableView registerNib:[UINib nibWithNibName:@"ShowCell" bundle:nil] forCellReuseIdentifier:@"ShowCell"];
        cell = [tableView dequeueReusableCellWithIdentifier:@"ShowCell"];
    }
    Show *item = [self showForIndexPath:indexPath];
    [cell configureForShow:item];
    return cell;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    if (dayOfWeek == 0) {
        return sectionIndexTitles;
    }
    else
        return nil;
}

@end
