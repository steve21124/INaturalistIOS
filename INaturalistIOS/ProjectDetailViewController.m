//
//  ProjectDetailViewController.m
//  iNaturalist
//
//  Created by Ken-ichi Ueda on 3/14/12.
//  Copyright (c) 2012 iNaturalist. All rights reserved.
//

#import "ProjectDetailViewController.h"
#import "Observation.h"
#import "Project.h"
#import "ProjectObservation.h"
#import "List.h"
#import "ListedTaxon.h"
#import "Taxon.h"
#import "ImageStore.h"
#import "DejalActivityView.h"
#import "TaxonDetailViewController.h"

static const int ListedTaxonCellImageTag = 1;
static const int ListedTaxonCellTitleTag = 2;
static const int ListedTaxonCellSubtitleTag = 3;

@implementation ProjectDetailViewController
@synthesize project = _project;
@synthesize listedTaxa = _listedTaxa;
@synthesize projectIcon = _projectIcon;
@synthesize projectTitle = _projectTitle;
@synthesize projectSubtitle = _projectSubtitle;
@synthesize loader = _loader;
@synthesize lastSyncedAt = _lastSyncedAt;

- (IBAction)clickedSync:(id)sender {
    [self sync];
}

- (void)clickedAdd:(id)sender event:(UIEvent *)event
{
    CGPoint currentTouchPosition = [event.allTouches.anyObject locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:currentTouchPosition];
    
    ListedTaxon *lt = [self.listedTaxa objectAtIndex:indexPath.row];
    [self performSegueWithIdentifier:@"AddObservationSegue" sender:lt];
}

- (void)sync
{
    [DejalBezelActivityView activityViewForView:self.navigationController.view
                                      withLabel:@"Syncing list..."];
    [[RKObjectManager sharedManager] loadObjectsAtResourcePath:[NSString stringWithFormat:@"/lists/%d.json", self.project.listID.intValue] 
                                                      delegate:self];
}

- (void)stopSync
{
    [DejalBezelActivityView removeView];
    [[[[RKObjectManager sharedManager] client] requestQueue] cancelAllRequests];
    [self loadData];
    [[self tableView] reloadData];
}

- (void)loadData
{
    NSArray *sorts = [NSArray arrayWithObjects:
                      [[NSSortDescriptor alloc] initWithKey:@"ancestry" ascending:YES], 
                      [[NSSortDescriptor alloc] initWithKey:@"recordID" ascending:YES], 
                      nil];
    self.listedTaxa = [NSMutableArray arrayWithArray:
                       [self.project.projectList.listedTaxa.allObjects sortedArrayUsingDescriptors:sorts]];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"AddObservationSegue"]) {
        ObservationDetailViewController *vc = [segue destinationViewController];
        [vc setDelegate:self];
        Observation *o = [Observation object];
        ProjectObservation *po = [ProjectObservation object];
        po.observation = o;
        po.project = self.project;
        o.localObservedOn = [NSDate date];
        if ([sender isKindOfClass:ListedTaxon.class]) {
            ListedTaxon *lt = sender;
            o.taxon = lt.taxon;
            o.speciesGuess = lt.taxonDefaultName;
        }
        [vc setObservation:o];
    } else if ([segue.identifier isEqualToString:@"SciTaxonSegue"] || [segue.identifier isEqualToString:@"ComTaxonSegue"]) {
        TaxonDetailViewController *vc = [segue destinationViewController];
        ListedTaxon *lt = [self.listedTaxa
                           objectAtIndex:[[self.tableView 
                                           indexPathForSelectedRow] row]];
        vc.taxon = lt.taxon;
    }
}

#pragma mark - lifecycle
- (void)viewDidLoad
{
    if (!self.listedTaxa) {
        [self loadData];
    }
    self.projectIcon.defaultImage = [UIImage imageNamed:@"projects.png"];
    self.projectIcon.urlPath = self.project.iconURL;
    self.projectTitle.text = self.project.title;
    self.projectSubtitle.textColor = [UIColor grayColor];
    self.projectSubtitle.font = [UIFont systemFontOfSize:12.0];
    self.projectSubtitle.text = [TTStyledText textFromXHTML:self.project.desc
                                            lineBreaks:NO 
                                                  URLs:YES];
    
    CAGradientLayer *lyr = [CAGradientLayer layer];
    lyr.colors = [NSArray arrayWithObjects:
                  (id)[UIColor whiteColor].CGColor, 
                  (id)[UIColor colorWithRed:(220/255.0)  green:(220/255.0)  blue:(220/255.0)  alpha:1.0].CGColor, nil];
    lyr.locations = [NSArray arrayWithObjects:[NSNumber numberWithFloat:0], [NSNumber numberWithFloat:1], nil];
    lyr.frame = self.tableView.tableHeaderView.bounds;
    [self.tableView.tableHeaderView.layer insertSublayer:lyr atIndex:0];
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self.navigationController setToolbarHidden:YES];
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    if (self.listedTaxa.count == 0 && !self.lastSyncedAt) {
        [self sync];
    }
    [super viewDidAppear:animated];
}

- (void)viewDidUnload {
    [self setProjectIcon:nil];
    [self setProjectTitle:nil];
    [self setProjectSubtitle:nil];
    [super viewDidUnload];
}

#pragma mark - Table view data source
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.listedTaxa.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ListedTaxon *lt = [self.listedTaxa objectAtIndex:[indexPath row]];
    
    NSString *cellIdentifier = [lt.taxonName isEqualToString:lt.taxonDefaultName] ? @"ListedTaxonOneNameCell" : @"ListedTaxonTwoNamesCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    
    UIButton *addButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 50, 35)];
    [addButton setBackgroundImage:[UIImage imageNamed:@"add_button"] 
                         forState:UIControlStateNormal];
    [addButton setBackgroundImage:[UIImage imageNamed:@"add_button_highlight"] 
                         forState:UIControlStateHighlighted];
    [addButton setTitle:@"Add" forState:UIControlStateNormal];
    [addButton setTitle:@"Add" forState:UIControlStateHighlighted];
    addButton.titleLabel.textColor = [UIColor whiteColor];
    addButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [addButton addTarget:self action:@selector(clickedAdd:event:) forControlEvents:UIControlEventTouchUpInside];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.accessoryView = addButton;
    
    TTImageView *imageView = (TTImageView *)[cell viewWithTag:ListedTaxonCellImageTag];
    [imageView unsetImage];
    UILabel *titleLabel = (UILabel *)[cell viewWithTag:ListedTaxonCellTitleTag];
    titleLabel.text = lt.taxonDefaultName;
    imageView.defaultImage = [[ImageStore sharedImageStore] iconicTaxonImageForName:lt.iconicTaxonName];
    imageView.urlPath = lt.photoURL;
    if ([lt.taxonName isEqualToString:lt.taxonDefaultName]) {
        if (lt.taxon.rankLevel.intValue >= 30) {
            titleLabel.font = [UIFont boldSystemFontOfSize:titleLabel.font.pointSize];
        } else {
            titleLabel.font = [UIFont fontWithName:@"Helvetica-BoldOblique" size:titleLabel.font.pointSize];
        }
    } else {
        UILabel *subtitleLabel = (UILabel *)[cell viewWithTag:ListedTaxonCellSubtitleTag];
        subtitleLabel.text = lt.taxonName;
    }
    
    return cell;
}

#pragma mark - RKObjectLoaderDelegate
- (void)objectLoader:(RKObjectLoader *)objectLoader didLoadObjects:(NSArray *)objects
{
    if (objects.count == 0) return;
    NSDate *now = [NSDate date];
    for (INatModel *o in objects) {
        [o setSyncedAt:now];
    }
    
    NSArray *rejects = [ListedTaxon objectsWithPredicate:
                        [NSPredicate predicateWithFormat:@"listID = %d AND syncedAt < %@", 
                         self.project.listID.intValue, now]];
    for (ListedTaxon *lt in rejects) {
        [lt deleteEntity];
    }
    
    [[[RKObjectManager sharedManager] objectStore] save];
    
    [self stopSync];
}

- (void)objectLoader:(RKObjectLoader *)objectLoader didFailWithError:(NSError *)error {
    // was running into a bug in release build config where the object loader was 
    // getting deallocated after handling an error.  This is a kludge.
    self.loader = objectLoader;
    
    [self stopSync];
    NSString *errorMsg;
    bool jsonParsingError = false, authFailure = false;
    switch (objectLoader.response.statusCode) {
            // UNPROCESSABLE ENTITY
        case 422:
            errorMsg = @"Unprocessable entity";
            break;
            
        default:
            // KLUDGE!! RestKit doesn't seem to handle failed auth very well
            jsonParsingError = [error.domain isEqualToString:@"JKErrorDomain"] && error.code == -1;
            authFailure = [error.domain isEqualToString:@"NSURLErrorDomain"] && error.code == -1012;
            errorMsg = error.localizedDescription;
    }
    
    UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Whoops!" 
                                                 message:[NSString stringWithFormat:@"Looks like there was an error: %@", errorMsg]
                                                delegate:self 
                                       cancelButtonTitle:@"OK" 
                                       otherButtonTitles:nil];
    [av show];
}

#pragma mark - ObservationDetailViewControllerDelegate
- (void)observationDetailViewControllerDidSave:(ObservationDetailViewController *)controller
{
    [self dismissViewControllerAnimated:YES completion:nil];
    [[self navigationController] popToViewController:self animated:YES];
}

- (void)observationDetailViewControllerDidCancel:(ObservationDetailViewController *)controller
{
    [self dismissViewControllerAnimated:YES completion:nil];
    [[self navigationController] popToViewController:self animated:YES];
}
@end