//  Created by Monte Hurd on 12/18/13.

#import "MainMenuTableViewController.h"
#import "MainMenuSectionHeadingLabel.h"

#import "ArticleDataContextSingleton.h"
#import "NSManagedObjectContext+SimpleFetch.h"
#import "ArticleCoreDataObjects.h"
#import "Article+Convenience.h"

#import "MWNetworkOp.h"
#import "QueuesSingleton.h"
#import "SessionSingleton.h"
#import "NSURLRequest+DictionaryRequest.h"
#import "MWNetworkActivityIndicatorManager.h"

// Section indexes.
#define SECTION_MENU_OPTIONS 0
#define SECTION_ARTICLE_OPTIONS 1
#define SECTION_SEARCH_LANGUAGE_OPTIONS 2

// Row indexes.
#define ROW_SAVED_PAGES 1

// Language toggle text.
#define LANGUAGES_TOGGLE_TEXT_SHOW @" 🙉  Show Languages"
#define LANGUAGES_TOGGLE_TEXT_HIDE @" 🙈  Hide Languages"

// Language options text font/size/color.
#define LANGUAGES_TEXT_FONT @"Georgia"

#define LANGUAGES_TEXT_FONT_SIZE 17
#define LANGUAGES_TEXT_COLOR [UIColor blackColor]

#define LANGUAGES_CODE_FONT_SIZE 12
#define LANGUAGES_CODE_COLOR [UIColor lightGrayColor]

// Unsupported character set languages flag.
//TODO: figure out what to do with these languages!
// Set the define below to YES to see them in the list.
#define SHOW_LANGUAGES_WITH_UNSUPPORTED_CHARACTERS NO

@interface MainMenuTableViewController (){
}

@property (strong, atomic) NSMutableArray *tableData;
@property (atomic) BOOL hidePagesSection;
@property (atomic) BOOL showAllLanguages;

@property (strong, atomic) NSArray *unsupportedCharactersLanguageIds;

@end

@implementation MainMenuTableViewController

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.showAllLanguages = NO;
   
//TODO: figure out what to do with these:
    // Wiki language character sets that iOS doesn't seem to render properly...
    self.unsupportedCharactersLanguageIds = [@"my am km dv lez arc got ti" componentsSeparatedByString:@" "];
    
    self.hidePagesSection = NO;
    self.navigationItem.hidesBackButton = YES;
    self.tableData = [[NSMutableArray alloc] init];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
   
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;

    // Register the menu results cell for reuse
    [self.tableView registerNib:[UINib nibWithNibName:@"MainMenuResultPrototypeView" bundle:nil] forCellReuseIdentifier:@"MainMenuResultsCell"];
}

-(void)viewWillAppear:(BOOL)animated
{
    [self.tableData removeAllObjects];
    
    // Adds data for sections/rows to tableData (but does not load language rows)
    [self loadTableData];

    // Load language rows from file.
    [self addRowsToTableDataForLanguagesFromFile];

    // Add a "Show Languages" toggle.
    [self addToTableDataLanguagesToggleWithTitle:LANGUAGES_TOGGLE_TEXT_SHOW];

    NSString *lastViewedArticleTitle = [[NSUserDefaults standardUserDefaults] objectForKey:@"LastViewedArticleTitle"];
    if(!lastViewedArticleTitle || (lastViewedArticleTitle.length == 0)){
        self.hidePagesSection = YES;
        [[self sectionDict:SECTION_ARTICLE_OPTIONS][@"rows"] removeAllObjects];
    }else{
        self.hidePagesSection = NO;
    }
}

#pragma mark - Table section and row accessors

-(NSMutableDictionary *)sectionDict:(NSInteger)section
{
    return self.tableData[section];
}

-(NSMutableDictionary *)rowDict:(NSIndexPath *)indexPath
{
    return [self sectionDict:indexPath.section][@"rows"][indexPath.row];
}

#pragma mark - Table data

-(void)loadTableData
{
    NSString *lastViewedArticleTitle = [[NSUserDefaults standardUserDefaults] objectForKey:@"LastViewedArticleTitle"];

    self.tableData = [@[
                            
                            
                            [@{
                               @"key": @"menuOptions",
                               @"title": @"Show me...",
                               @"label": @"",
                               @"subTitle": @"",
                               @"rows": @[
                                       

                                       [@{
                                          @"key": @"history",
                                          @"title": @"📖  My Browsing History",
                                          @"label": @""
                                          } mutableCopy]

                                       
                                       ,

                                       [@{
                                          @"key": @"savedPages",
                                          @"title": @"💾  My Saved Pages",
                                          @"label": @""
                                          } mutableCopy]
                                       
                                       
                                       ]
                               } mutableCopy]
                            
                            
                            ,
                            
                            
                            [@{
                               @"key": @"articleOptions",
                               @"title": [NSString stringWithFormat:@"\"%@\"", lastViewedArticleTitle],
                               @"label": @"",
                               @"subTitle": @"",
                               @"rows": [@[
                                       [@{
                                          @"key": @"savePage",
                                          @"title": @"💾  Save for Offline Reading",
                                          @"label": @""
                                          } mutableCopy]
                                       
                                       ,
                                       [@{
                                          @"key": @"debugPage",
                                          @"title": @"👀 Debug",
                                          @"label": @""
                                          } mutableCopy]
                                       
                                       ] mutableCopy]
                               } mutableCopy]
                            ,
                            
                            
                            [@{
                               @"key": @"searchLanguageOptions",
                               @"title": @"Language Wiki To Search",
                               @"label": @"",
                               @"subTitle": @"",
                               @"rows": [@[] mutableCopy]
                               } mutableCopy]
                            
                            
                            ] mutableCopy];
}

-(void)addRowsToTableDataForLanguagesFromFile
{
    NSMutableArray *languagesToShow = [@[] mutableCopy];
    NSMutableArray *languagesFromFile = [self getLanguagesFromFile];
    for (NSDictionary *langDict in languagesFromFile) {

        // If we're not showing all languages, just show the currently selected language.
        if (!self.showAllLanguages) {
            //NSLog(@"langDict[@\"code\"] = %@", langDict[@"code"]);
            //NSLog(@"[SessionSingleton sharedInstance].domain = %@", [SessionSingleton sharedInstance].domain);
            if (![langDict[@"code"] isEqualToString:[SessionSingleton sharedInstance].domain]) continue;
        }
        if (!SHOW_LANGUAGES_WITH_UNSUPPORTED_CHARACTERS) {
            if ([self.unsupportedCharactersLanguageIds indexOfObject:langDict[@"code"]] != NSNotFound) continue;
        }
        [languagesToShow addObject:langDict];
    }
    [self addToTableDataRowsForLanguages:languagesToShow];
}

#pragma mark - Memory

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self.tableData count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSArray *sectionRows = [self sectionDict:section][@"rows"];
    return sectionRows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MainMenuResultsCell" forIndexPath:indexPath];

    NSMutableDictionary *row = [self rowDict:indexPath];
    
    row[@"label"] = cell.textLabel;

    if ((indexPath.section == SECTION_SEARCH_LANGUAGE_OPTIONS) && [row objectForKey:@"canonicalLanguageName"]) {
        cell.textLabel.attributedText = [self getAttributedTitleForLanguageRow:row];
    }else{
        cell.textLabel.text = row[@"title"];
    }
    return cell;
}

#pragma mark - Language row attributed title

-(NSAttributedString *)getAttributedTitleForLanguageRow:(NSDictionary *)row
{
    NSString *title = row[@"languageName"];
    NSString *language = [NSString stringWithFormat:@"\n%@", row[@"canonicalLanguageName"]];

    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment = NSTextAlignmentLeft;

    NSMutableAttributedString *(^styleText)(NSString *, CGFloat, UIColor *) = ^NSMutableAttributedString *(NSString *str, CGFloat size, UIColor *color){
        return [[NSMutableAttributedString alloc] initWithString:str attributes: @{
            NSFontAttributeName : [UIFont fontWithName:LANGUAGES_TEXT_FONT size:size],
            NSParagraphStyleAttributeName : paragraphStyle,
            NSForegroundColorAttributeName : color,
        }];
    };

    NSMutableAttributedString *attributedTitle = styleText(title, LANGUAGES_TEXT_FONT_SIZE, LANGUAGES_TEXT_COLOR);
    NSMutableAttributedString *attributedLanguage = styleText(language, LANGUAGES_CODE_FONT_SIZE, LANGUAGES_CODE_COLOR);

    [attributedTitle appendAttributedString:attributedLanguage];
    return attributedTitle;
}

#pragma mark - Table view delegate

-(UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if ((section == SECTION_ARTICLE_OPTIONS) && self.hidePagesSection) {
        return nil;
    }

    NSMutableDictionary *sectionDict = [self sectionDict:section];

    // Don't show header if no items in this section.
    NSArray *sectionRows = sectionDict[@"rows"];
    if (sectionRows.count == 0) {
        return nil;
    }
    
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = [UIColor colorWithWhite:0.97f alpha:0.97f];
    
    MainMenuSectionHeadingLabel *label = [[MainMenuSectionHeadingLabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    
    label.useDottedLine = NO; // (section == SECTION_MENU_OPTIONS) ? NO : YES ;
    
    NSString *title = sectionDict[@"title"];
    //NSString *subTitle = dict[@"subTitle"];
    
    //label.text = [NSString stringWithFormat:@"  %@ - %@", title, subTitle];
    label.text = [NSString stringWithFormat:@"%@", title];
    
    sectionDict[@"label"] = label;
    
    [view addSubview:label];
    [view addConstraints: [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-10-[label]-10-|" options:0 metrics:nil views:@{@"label":label}]];
    [view addConstraints: [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[label]-0-|" options:0 metrics:nil views:@{@"label":label}]];
    
    return view;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 53;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section;
{
    if (section == SECTION_ARTICLE_OPTIONS && self.hidePagesSection) {
        return 0.01;
    }
    return 63;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *sectionDict = [self sectionDict:indexPath.section];

    NSString *selectedSectionKey = sectionDict[@"key"];

    NSMutableDictionary *rowDict = [self rowDict:indexPath];
    NSString *selectedRowKey = rowDict[@"key"];
    //NSLog(@"menu item selection key = %@", selectedKey);
    
    if ([selectedRowKey isEqualToString:@"history"]) {
        [self.navigationController popViewControllerAnimated:NO];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"HistoryToggle" object:self userInfo:nil];
    }else if ([selectedRowKey isEqualToString:@"savedPages"]) {
        [self.navigationController popViewControllerAnimated:NO];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SavedPagesToggle" object:self userInfo:nil];
    }else if ([selectedRowKey isEqualToString:@"savePage"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SavePage" object:self userInfo:nil];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];

        [self animateArticleTitleMovingToSavedPages];
    }else if ([selectedRowKey isEqualToString:@"debugPage"]) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        
        NSLog(@"DEBUG PAGE!");

    }else if ([selectedSectionKey isEqualToString:@"searchLanguageOptions"]) {

        if ([selectedRowKey isEqualToString:@"show_languages"]) {
            self.showAllLanguages = !self.showAllLanguages;

           [[self sectionDict:SECTION_SEARCH_LANGUAGE_OPTIONS][@"rows"] removeAllObjects];
            // Show single selected lang option above the "Show Languages" toggle.
            if (!self.showAllLanguages)[self addRowsToTableDataForLanguagesFromFile];
            
            if (self.showAllLanguages) {
                [self addToTableDataLanguagesToggleWithTitle:LANGUAGES_TOGGLE_TEXT_HIDE];
            }else{
                [self addToTableDataLanguagesToggleWithTitle:LANGUAGES_TOGGLE_TEXT_SHOW];
            }
            // Show huge language list below the "Hide Languages" toggle.
            if (self.showAllLanguages)[self addRowsToTableDataForLanguagesFromFile];

            [self.tableView reloadData];
            
            // Now that the language list has been revealed, scroll to the current selection.
            if (self.showAllLanguages) {
                NSIndexPath *selectedLangIndexPath = [self getIndexPathOfSelectedLanguage];
                [tableView selectRowAtIndexPath:selectedLangIndexPath animated:YES scrollPosition:UITableViewScrollPositionMiddle];
            }
        }else{
            //NSLog(@"selectedKey =  %@", selectedRowKey);
            [tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
            [self switchPreferredLanguageToId:selectedRowKey name:rowDict[@"languageName"]];
        }
    }
}

-(void)addToTableDataLanguagesToggleWithTitle:(NSString *)title
{
    [[self sectionDict:SECTION_SEARCH_LANGUAGE_OPTIONS][@"rows"] addObject:
     [@{
        @"key": @"show_languages",
        @"title": title,
        @"label": @"",
        } mutableCopy]
     ];
}

-(NSIndexPath *)getIndexPathOfSelectedLanguage
{
    NSMutableDictionary *sectionDict = [self sectionDict:SECTION_SEARCH_LANGUAGE_OPTIONS];
    NSArray *rows = sectionDict[@"rows"];
    for (NSInteger i = 0; i < rows.count; i++) {
        if ([rows[i][@"key"] isEqualToString:[SessionSingleton sharedInstance].domain]) {
            return [NSIndexPath indexPathForRow:i inSection:SECTION_SEARCH_LANGUAGE_OPTIONS];
        }
    }
    return [NSIndexPath indexPathForRow:-1 inSection:SECTION_SEARCH_LANGUAGE_OPTIONS];
}

#pragma mark - Sage page animation

-(void)animateArticleTitleMovingToSavedPages
{
    NSIndexPath *savedPagesIndexPath = [NSIndexPath indexPathForRow:ROW_SAVED_PAGES inSection:SECTION_MENU_OPTIONS];
    NSDictionary *savedPagesRow = [self rowDict:savedPagesIndexPath];
    NSDictionary *articleSection = [self sectionDict:SECTION_ARTICLE_OPTIONS];

    UILabel *savedPagesLabel = savedPagesRow[@"label"];
    UILabel *articleTitleLabel = articleSection[@"label"];
    
    CGAffineTransform scale = CGAffineTransformMakeScale(0.4, 0.4);
    CGPoint destPoint = [self getLocationForView:savedPagesLabel xf:scale];
    
    [self animateView:[self getLabelCopyToAnimate:articleTitleLabel] toDestination:destPoint afterDelay:0.0 duration:0.45f transform:scale];
    [self animateView:[self getLabelCopyToAnimate:articleTitleLabel] toDestination:destPoint afterDelay:0.06 duration:0.45f transform:scale];
    [self animateView:[self getLabelCopyToAnimate:articleTitleLabel] toDestination:destPoint afterDelay:0.12 duration:0.45f transform:scale];
    [self animateView:[self getLabelCopyToAnimate:articleTitleLabel] toDestination:destPoint afterDelay:0.18 duration:0.45f transform:scale];

    [self animateAndRewindXF:CATransform3DMakeScale(1.08f, 1.08f, 1.0f) forView:savedPagesLabel afterDelay:0.33 duration:0.17];
}

-(void)animateAndRewindXF:(CATransform3D)xf forView:(UIView *)view afterDelay:(CGFloat)delay duration:(CGFloat)duration
{
    CABasicAnimation *(^animatePathToValue)(NSString *, NSValue *, CGFloat, CGFloat) = ^(NSString *path, NSValue *toValue, CGFloat duration, CGFloat delay){
        CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:path];
        a.fillMode = kCAFillModeForwards;
        a.autoreverses = YES;
        a.duration = duration;
        a.removedOnCompletion = YES;
        [a setBeginTime:CACurrentMediaTime() + delay];
        a.toValue = toValue;
        return a;
    };
    [view.layer addAnimation:animatePathToValue(@"transform", [NSValue valueWithCATransform3D:xf], duration, delay) forKey:nil];
}

-(UILabel *)getLabelCopyToAnimate:(UILabel *)labelToCopy
{
    UILabel *labelCopy = [[UILabel alloc] init];
    CGRect sourceRect = [labelToCopy convertRect:labelToCopy.bounds toView:self.tableView];
    labelCopy.frame = sourceRect;
    labelCopy.text = labelToCopy.text;
    labelCopy.font = labelToCopy.font;
    labelCopy.textColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    labelCopy.textAlignment = labelToCopy.textAlignment;
    labelCopy.lineBreakMode = labelToCopy.lineBreakMode;
    labelCopy.numberOfLines = labelToCopy.numberOfLines;
    [self.tableView addSubview:labelCopy];
    return labelCopy;
}

-(CGPoint)getLocationForView:(UIView *)view xf:(CGAffineTransform)xf
{
    CGPoint point = [view convertPoint:view.center toView:self.tableView];
    CGPoint scaledPoint = [view convertPoint:CGPointApplyAffineTransform(view.center, xf) toView:self.tableView];
    scaledPoint.y = point.y;
    return scaledPoint;
}

-(void)animateView:(UIView *)view toDestination:(CGPoint)destPoint afterDelay:(CGFloat)delay duration:(CGFloat)duration transform:(CGAffineTransform)xf
{
    [UIView animateWithDuration:duration delay:delay options:UIViewAnimationOptionCurveEaseInOut animations:^{
        view.center = destPoint;
        view.alpha = 0.3f;
        view.transform = xf;
    }completion:^(BOOL finished) {
        [view removeFromSuperview];
    }];
}

#pragma mark - Search languages

-(void)addToTableDataRowsForLanguages:(NSArray *)languages
{
    NSMutableArray *rowDictionaries = @[].mutableCopy;
    
    for (NSDictionary *langDict in languages) {

        [rowDictionaries addObject:[@{
                        @"key": langDict[@"code"],
                        @"canonicalLanguageName": langDict[@"canonical_name"],
                        @"languageName": langDict[@"name"],
                        @"label": @"",
                        } mutableCopy]
         ];
    }
   
    [[self sectionDict:SECTION_SEARCH_LANGUAGE_OPTIONS][@"rows"] addObjectsFromArray:rowDictionaries];
}

-(void)switchPreferredLanguageToId:(NSString *)languageId name:(NSString *)name
{
    [SessionSingleton sharedInstance].domain = languageId;
    [SessionSingleton sharedInstance].domainName = name;
}

#pragma mark - Retrieve json language file

-(NSMutableArray *)getLanguagesFromFile
{
    NSError *error = nil;
    NSData *fileData = [NSData dataWithContentsOfFile:[self bundledLanguagesPath] options:0 error:&error];
    if (error) return [@[] mutableCopy];
    error = nil;
    NSArray *result = [NSJSONSerialization JSONObjectWithData:fileData options:0 error:&error];
    return (error) ? [@[] mutableCopy]: [result mutableCopy];
}

- (NSString *)bundledLanguagesPath
{
    return [[[NSBundle mainBundle] bundlePath] stringByAppendingString:@"/Languages/languages.json"];
}

@end
