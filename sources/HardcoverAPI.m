#import "HardcoverAPI.h"

@implementation HardcoverUser
@end

@implementation HardcoverAPI

+ (instancetype)sharedInstance
{
    static HardcoverAPI   *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ sharedInstance = [[HardcoverAPI alloc] init]; });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _apiToken     = [self loadSavedToken];
        _isAuthorized = NO;
        _currentUser  = nil;
    }
    return self;
}

- (void)setAPIToken:(NSString *)token
{
    _apiToken     = token;
    _isAuthorized = NO;
    _currentUser  = nil;
}

- (void)authorizeWithCompletion:(void (^)(BOOL success, HardcoverUser *user,
                                          NSError *error))completion
{
    if (!_apiToken || _apiToken.length == 0)
    {
        NSError *error =
            [NSError errorWithDomain:@"HardcoverAPI"
                                code:400
                            userInfo:@{NSLocalizedDescriptionKey : @"No API token provided"}];
        if (completion)
            completion(NO, nil, error);
        return;
    }

    [self makeGraphQLRequest:@"query Me { me { id username birthdate books_count flair "
                             @"followers_count followed_users_count location name pro "
                             @"pronoun_personal pronoun_possessive sign_in_count image { url } } }"
              withCompletion:^(NSDictionary *response, NSError *error) {
                  if (error)
                  {
                      self.isAuthorized = NO;
                      self.currentUser  = nil;
                      if (completion)
                          completion(NO, nil, error);
                      return;
                  }

                  NSDictionary *data =
                      [response isKindOfClass:[NSDictionary class]] ? response[@"data"] : nil;
                  NSArray *meArray = [data isKindOfClass:[NSDictionary class]] ? data[@"me"] : nil;

                  if (!meArray || meArray.count == 0)
                  {
                      NSError *authError = [NSError
                          errorWithDomain:@"HardcoverAPI"
                                     code:401
                                 userInfo:@{NSLocalizedDescriptionKey : @"Invalid API token"}];
                      self.isAuthorized  = NO;
                      self.currentUser   = nil;
                      if (completion)
                          completion(NO, nil, authError);
                      return;
                  }

                  NSDictionary  *userDict = [meArray.firstObject isKindOfClass:[NSDictionary class]]
                                                ? meArray.firstObject
                                                : @{};
                  HardcoverUser *user     = [[HardcoverUser alloc] init];
                  id             uidVal   = userDict[@"id"];
                  user.userId             = [uidVal isKindOfClass:[NSNumber class]] ? uidVal : nil;
                  id unameVal             = userDict[@"username"];
                  user.username = [unameVal isKindOfClass:[NSString class]] ? unameVal : nil;
                  id nameVal    = userDict[@"name"];
                  user.name     = [nameVal isKindOfClass:[NSString class]] ? nameVal : nil;
                  id            imageDictVal = userDict[@"image"];
                  NSDictionary *imageDict =
                      [imageDictVal isKindOfClass:[NSDictionary class]] ? imageDictVal : @{};
                  id imageURLVal = imageDict[@"url"];
                  user.imageURL  = [imageURLVal isKindOfClass:[NSString class]] ? imageURLVal : nil;
                  user.birthdate = userDict[@"birthdate"];
                  user.flair     = userDict[@"flair"];
                  user.location  = userDict[@"location"];
                  user.pronoun_personal   = userDict[@"pronoun_personal"];
                  user.pronoun_possessive = userDict[@"pronoun_possessive"];
                  id booksCntVal          = userDict[@"books_count"];
                  user.books_count =
                      [booksCntVal isKindOfClass:[NSNumber class]] ? booksCntVal : nil;
                  id followersCntVal = userDict[@"followers_count"];
                  user.followers_count =
                      [followersCntVal isKindOfClass:[NSNumber class]] ? followersCntVal : nil;
                  id followedCntVal = userDict[@"followed_users_count"];
                  user.followed_users_count =
                      [followedCntVal isKindOfClass:[NSNumber class]] ? followedCntVal : nil;
                  id signInCntVal = userDict[@"sign_in_count"];
                  user.sign_in_count =
                      [signInCntVal isKindOfClass:[NSNumber class]] ? signInCntVal : nil;
                  user.pro = [userDict[@"pro"] boolValue];

                  self.currentUser  = user;
                  self.isAuthorized = YES;
                  [self saveToken:self.apiToken];

                  if (completion)
                      completion(YES, user, nil);
              }];
}

- (void)refreshUserWithCompletion:(void (^)(BOOL success, HardcoverUser *user,
                                            NSError *error))completion
{
    [self authorizeWithCompletion:completion];
}

- (void)fetchCurrentlyReadingForUserId:(NSNumber *)userId
                            completion:(void (^)(NSArray *items, NSError *error))completion
{
    if (!self.apiToken || self.apiToken.length == 0)
    {
        if (completion)
            completion(nil,
                       [NSError errorWithDomain:@"HardcoverAPI"
                                           code:401
                                       userInfo:@{NSLocalizedDescriptionKey : @"Missing token"}]);
        return;
    }
    if (!userId)
    {
        userId = self.currentUser.userId;
        if (!userId)
        {
            if (completion)
                completion(nil,
                           [NSError
                               errorWithDomain:@"HardcoverAPI"
                                          code:400
                                      userInfo:@{NSLocalizedDescriptionKey : @"Missing user id"}]);
            return;
        }
    }

    NSString *query = [NSString
        stringWithFormat:
            @"query CurrentlyReading {\n  users(where: {id: {_eq: %ld}}, limit: 1) {\n    id\n    "
            @"username\n    user_books(where: {status_id: {_eq: 2}}) {\n      user_book_reads {\n  "
            @"      user_book {\n          book {\n            id\n            title\n            "
            @"image { url }\n  "
            @"        }\n        }\n        edition { id asin audio_seconds }\n        "
            @"progress_seconds\n      }\n    }\n  }\n}",
            (long) userId.longLongValue];

    [self makeGraphQLRequest:query
              withCompletion:^(NSDictionary *response, NSError *error) {
                  if (error)
                  {
                      if (completion)
                          completion(nil, error);
                      return;
                  }
                  NSDictionary *data = response[@"data"];
                  NSArray *users = [data isKindOfClass:[NSDictionary class]] ? data[@"users"] : nil;
                  if (![users isKindOfClass:[NSArray class]] || users.count == 0)
                  {
                      if (completion)
                          completion(@[], nil);
                      return;
                  }
                  NSDictionary *user = users.firstObject;
                  NSArray      *user_books =
                      ([user isKindOfClass:[NSDictionary class]] ? user[@"user_books"] : nil);
                  NSMutableDictionary *itemsByBookId = [NSMutableDictionary dictionary];
                  NSMutableArray      *ordered       = [NSMutableArray array];
                  for (id ub in user_books)
                  {
                      if (![ub isKindOfClass:[NSDictionary class]])
                          continue;
                      NSArray *reads = ((NSDictionary *) ub)[@"user_book_reads"];
                      if (![reads isKindOfClass:[NSArray class]])
                          continue;
                      for (id readObj in reads)
                      {
                          if (![readObj isKindOfClass:[NSDictionary class]])
                              continue;
                          NSDictionary *read = (NSDictionary *) readObj;

                          id            userBookVal = read[@"user_book"];
                          NSDictionary *userBook =
                              [userBookVal isKindOfClass:[NSDictionary class]] ? userBookVal : @{};
                          id            bookVal = userBook[@"book"];
                          NSDictionary *book =
                              [bookVal isKindOfClass:[NSDictionary class]] ? bookVal : @{};

                          id            imageVal = book[@"image"];
                          NSDictionary *image =
                              [imageVal isKindOfClass:[NSDictionary class]] ? imageVal : @{};

                          id            editionVal = read[@"edition"];
                          NSDictionary *edition =
                              [editionVal isKindOfClass:[NSDictionary class]] ? editionVal : @{};

                          id        progressVal = read[@"progress_seconds"];
                          NSNumber *progressSeconds =
                              [progressVal isKindOfClass:[NSNumber class]] ? progressVal : @(0);
                          id        audioVal = edition[@"audio_seconds"];
                          NSNumber *audioSeconds =
                              [audioVal isKindOfClass:[NSNumber class]] ? audioVal : @(0);
                          id        bookIdVal = book[@"id"];
                          NSNumber *bookId =
                              [bookIdVal isKindOfClass:[NSNumber class]] ? bookIdVal : nil;
                          id        titleVal = book[@"title"];
                          NSString *title =
                              [titleVal isKindOfClass:[NSString class]] ? titleVal : @"";
                          id        coverVal = image[@"url"];
                          NSString *coverURL =
                              [coverVal isKindOfClass:[NSString class]] ? coverVal : @"";
                          id        asinVal = edition[@"asin"];
                          NSString *asin = [asinVal isKindOfClass:[NSString class]] ? asinVal : @"";

                          if (!bookId)
                              continue;

                          NSMutableDictionary *entry = itemsByBookId[bookId];
                          if (!entry)
                          {
                              entry            = [NSMutableDictionary dictionary];
                              entry[@"bookId"] = bookId;
                              if (title)
                                  entry[@"title"] = title;
                              if (coverURL)
                                  entry[@"coverURL"] = coverURL;
                              entry[@"asins"]       = [NSMutableSet set];
                              itemsByBookId[bookId] = entry;
                              [ordered addObject:entry];
                          }
                          if (asin.length > 0)
                          {
                              NSMutableSet *asins = entry[@"asins"];
                              [asins addObject:asin];
                          }
                          if (audioSeconds)
                              entry[@"audio_seconds"] = audioSeconds;
                          if (progressSeconds)
                              entry[@"progress_seconds"] = progressSeconds;
                      }
                  }
                  for (NSMutableDictionary *entry in ordered)
                  {
                      NSMutableSet *asins = entry[@"asins"];
                      if ([asins isKindOfClass:[NSMutableSet class]])
                          entry[@"asins"] = asins.allObjects ?: @[];
                  }
                  if (completion)
                      completion(ordered, nil);
              }];
}

- (void)makeGraphQLRequest:(NSString *)query
            withCompletion:(void (^)(NSDictionary *response, NSError *error))completion
{
    NSURL               *url     = [NSURL URLWithString:@"https://api.hardcover.app/v1/graphql"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    if (_apiToken.length > 0)
    {
        [request setValue:[NSString stringWithFormat:@"Bearer %@", _apiToken]
            forHTTPHeaderField:@"Authorization"];
    }

    NSDictionary *body = @{@"query" : query};
    NSError      *jsonError;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonError];

    if (jsonError)
    {
        if (completion)
            completion(nil, jsonError);
        return;
    }

    [request setHTTPBody:jsonData];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
              if (error)
              {
                  dispatch_async(dispatch_get_main_queue(), ^{
                      if (completion)
                          completion(nil, error);
                  });
                  return;
              }

              NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
              if (httpResponse.statusCode != 200)
              {
                  NSError *httpError = [NSError
                      errorWithDomain:@"HardcoverAPI"
                                 code:httpResponse.statusCode
                             userInfo:@{
                                 NSLocalizedDescriptionKey : [NSString
                                     stringWithFormat:@"HTTP %ld", (long) httpResponse.statusCode]
                             }];
                  dispatch_async(dispatch_get_main_queue(), ^{
                      if (completion)
                          completion(nil, httpError);
                  });
                  return;
              }

              NSError      *parseError;
              NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data
                                                                           options:0
                                                                             error:&parseError];

              dispatch_async(dispatch_get_main_queue(), ^{
                  if (parseError)
                  {
                      if (completion)
                          completion(nil, parseError);
                  }
                  else
                  {
                      if (completion)
                          completion(jsonResponse, nil);
                  }
              });
          }];

    [task resume];
}

- (void)saveToken:(NSString *)token
{
    if (token)
    {
        [[NSUserDefaults standardUserDefaults] setObject:token forKey:@"HardcoverAPIToken"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (NSString *)loadSavedToken
{
    return [[NSUserDefaults standardUserDefaults] stringForKey:@"HardcoverAPIToken"];
}

- (void)clearToken
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"HardcoverAPIToken"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    _apiToken     = nil;
    _isAuthorized = NO;
    _currentUser  = nil;
}

@end
