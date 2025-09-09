#import "HardcoverAPI.h"

@interface AudibleMetadataCapture : NSObject
+ (NSInteger)getCurrentProgressForASIN:(NSString *)asin;
@end

@interface                                                                     HardcoverAPI ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *asinToIDs;
@end

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
        _asinToIDs    = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)setAPIToken:(NSString *)token
{
    _apiToken     = token;
    _isAuthorized = NO;
    _currentUser  = nil;
}

- (void)makeGraphQLRequest:(NSString *)query
            withCompletion:(void (^)(NSDictionary *response, NSError *error))completion
{
    [self makeGraphQLRequestWithQuery:query variables:nil completion:completion];
}

- (void)makeGraphQLRequestWithQuery:(NSString *)query
                          variables:(NSDictionary *)variables
                         completion:(void (^)(NSDictionary *response, NSError *error))completion
{
    NSURL *url = [NSURL URLWithString:@"https://api-staging.hardcover.app/v1/graphql"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    if (_apiToken.length > 0)
    {
        [request setValue:[NSString stringWithFormat:@"Bearer %@", _apiToken]
            forHTTPHeaderField:@"Authorization"];
    }

    NSMutableDictionary *body = [@{@"query" : query} mutableCopy];
    if (variables)
    {
        body[@"variables"] = variables;
    }

    NSError *jsonError;
    NSData  *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonError];

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
              dispatch_async(dispatch_get_main_queue(), ^{
                  if (error)
                  {
                      if (completion)
                          completion(nil, error);
                      return;
                  }

                  if (!data)
                  {
                      NSError *noDataError = [NSError
                          errorWithDomain:@"HardcoverAPI"
                                     code:500
                                 userInfo:@{NSLocalizedDescriptionKey : @"No data received"}];
                      if (completion)
                          completion(nil, noDataError);
                      return;
                  }

                  NSError      *parseError;
                  NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data
                                                                               options:0
                                                                                 error:&parseError];

                  if (parseError)
                  {
                      if (completion)
                          completion(nil, parseError);
                      return;
                  }

                  NSArray *errors = responseDict[@"errors"];
                  if (errors && [errors isKindOfClass:[NSArray class]] && errors.count > 0)
                  {
                      NSDictionary *firstError   = errors.firstObject;
                      NSString     *errorMessage = firstError[@"message"] ?: @"GraphQL error";
                      NSError      *gqlError =
                          [NSError errorWithDomain:@"HardcoverAPI"
                                              code:400
                                          userInfo:@{NSLocalizedDescriptionKey : errorMessage}];
                      if (completion)
                          completion(nil, gqlError);
                      return;
                  }

                  if (completion)
                      completion(responseDict, nil);
              });
          }];

    [task resume];
}

- (void)authorizeWithCompletion:(void (^)(BOOL success, HardcoverUser *user,
                                          NSError *error))completion
{
    if (!_apiToken || _apiToken.length == 0)
    {
        NSError *error =
            [NSError errorWithDomain:@"HardcoverAPI"
                                code:401
                            userInfo:@{NSLocalizedDescriptionKey : @"No API token provided"}];
        if (completion)
            completion(NO, nil, error);
        return;
    }

    [self makeGraphQLRequest:@"query Me { me { id username birthdate books_count flair "
                             @"followers_count followed_users_count location name pro "
                             @"pronoun_personal pronoun_possessive sign_in_count image { url } "
                             @"librarian_roles } }"
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
                                 userInfo:@{
                                     NSLocalizedDescriptionKey : @"Invalid response or no user"
                                 }];
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
                  user.pro    = [userDict[@"pro"] boolValue];
                  id rolesVal = userDict[@"librarian_roles"];
                  if ([rolesVal isKindOfClass:[NSArray class]])
                  {
                      NSMutableArray *roles = [NSMutableArray array];
                      for (id r in (NSArray *) rolesVal)
                      {
                          if ([r isKindOfClass:[NSString class]])
                              [roles addObject:r];
                      }
                      user.librarian_roles = roles.count ? roles : nil;
                  }

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
    if (!_apiToken || _apiToken.length == 0)
    {
        NSError *error =
            [NSError errorWithDomain:@"HardcoverAPI"
                                code:400
                            userInfo:@{NSLocalizedDescriptionKey : @"No API token provided"}];
        if (completion)
            completion(nil, error);
        return;
    }

    if (!userId)
    {
        userId = self.currentUser.userId;
        if (!userId)
        {
            NSError *error =
                [NSError errorWithDomain:@"HardcoverAPI"
                                    code:400
                                userInfo:@{NSLocalizedDescriptionKey : @"Missing user id"}];
            if (completion)
                completion(nil, error);
            return;
        }
    }

    NSString *query = [NSString stringWithFormat:@"query CurrentlyReading {\n"
                                                 @"  users(where: {id: {_eq: %ld}}, limit: 1) {\n"
                                                 @"    id\n"
                                                 @"    username\n"
                                                 @"    user_books(where: {status_id: {_eq: 2}}) {\n"
                                                 @"      id\n"
                                                 @"      book {\n"
                                                 @"        id\n"
                                                 @"        title\n"
                                                 @"        image { url }\n"
                                                 @"        contributions {\n"
                                                 @"          contribution\n"
                                                 @"          author {\n"
                                                 @"            id\n"
                                                 @"            name\n"
                                                 @"          }\n"
                                                 @"        }\n"
                                                 @"      }\n"
                                                 @"      user_book_reads {\n"
                                                 @"        user_book {\n"
                                                 @"          id\n"
                                                 @"          book {\n"
                                                 @"            id\n"
                                                 @"            title\n"
                                                 @"            image { url }\n"
                                                 @"          }\n"
                                                 @"        }\n"
                                                 @"        edition { id asin audio_seconds }\n"
                                                 @"        progress_seconds\n"
                                                 @"      }\n"
                                                 @"    }\n"
                                                 @"  }\n"
                                                 @"}",
                                                 (long) userId.longLongValue];

    [self
        makeGraphQLRequest:query
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
                [self.asinToIDs removeAllObjects];

                NSMutableDictionary *itemsByBookId = [NSMutableDictionary dictionary];
                NSMutableArray      *ordered       = [NSMutableArray array];

                for (id ub in user_books)
                {
                    if (![ub isKindOfClass:[NSDictionary class]])
                        continue;

                    NSNumber *userBookId =
                        [ub[@"id"] isKindOfClass:[NSNumber class]] ? ub[@"id"] : nil;

                    id            bookVal = ((NSDictionary *) ub)[@"book"];
                    NSDictionary *book =
                        [bookVal isKindOfClass:[NSDictionary class]] ? bookVal : @{};
                    NSArray *contributions = [book[@"contributions"] isKindOfClass:[NSArray class]]
                                                 ? book[@"contributions"]
                                                 : @[];

                    NSMutableArray *contributorIds = [NSMutableArray array];
                    for (id contrib in contributions)
                    {
                        if ([contrib isKindOfClass:[NSDictionary class]])
                        {
                            id authorVal = ((NSDictionary *) contrib)[@"author"];
                            if ([authorVal isKindOfClass:[NSDictionary class]])
                            {
                                id authorIdVal = ((NSDictionary *) authorVal)[@"id"];
                                if ([authorIdVal isKindOfClass:[NSNumber class]])
                                {
                                    [contributorIds addObject:authorIdVal];
                                }
                            }
                        }
                    }

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
                        NSNumber *editionId =
                            [edition[@"id"] isKindOfClass:[NSNumber class]] ? edition[@"id"] : nil;

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
                            entry[@"asins"]          = [NSMutableSet set];
                            entry[@"contributorIds"] = contributorIds;
                            itemsByBookId[bookId]    = entry;
                            [ordered addObject:entry];
                        }

                        if (asin.length > 0)
                        {
                            NSMutableSet *asins = entry[@"asins"];
                            [asins addObject:asin];
                            if (userBookId && editionId)
                            {
                                self.asinToIDs[asin] =
                                    @{@"user_book_id" : userBookId, @"edition_id" : editionId};
                            }
                        }

                        if (audioSeconds)
                            entry[@"audio_seconds"] = audioSeconds;
                        if (progressSeconds)
                            entry[@"progress_seconds"] = progressSeconds;
                        if (userBookId)
                            entry[@"user_book_id"] = userBookId;
                        if (editionId)
                            entry[@"edition_id"] = editionId;
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

- (void)updateListeningProgressForASIN:(NSString *)asin
                       progressSeconds:(NSInteger)seconds
                          totalSeconds:(NSInteger)totalSeconds
                            completion:(void (^_Nullable)(BOOL success,
                                                          NSError *_Nullable error))completion
{
    if (!self.apiToken || self.apiToken.length == 0)
    {
        NSError *error = [NSError errorWithDomain:@"HardcoverAPI"
                                             code:401
                                         userInfo:@{NSLocalizedDescriptionKey : @"No API token"}];
        if (completion)
            completion(NO, error);
        return;
    }

    if (!self.currentUser.userId)
    {
        [self authorizeWithCompletion:^(BOOL success, HardcoverUser *user, NSError *authError) {
            if (success && user.userId)
            {
                [self updateListeningProgressForASIN:asin
                                     progressSeconds:seconds
                                        totalSeconds:totalSeconds
                                          completion:completion];
            }
            else
            {
                NSError *error =
                    authError
                        ?: [NSError errorWithDomain:@"HardcoverAPI"
                                               code:401
                                           userInfo:@{
                                               NSLocalizedDescriptionKey : @"Authentication failed"
                                           }];
                if (completion)
                    completion(NO, error);
            }
        }];
        return;
    }

    if (!asin || asin.length == 0)
    {
        NSError *error =
            [NSError errorWithDomain:@"HardcoverAPI"
                                code:400
                            userInfo:@{NSLocalizedDescriptionKey : @"No ASIN provided"}];
        if (completion)
            completion(NO, error);
        return;
    }

    [self
        getLatestReadForASIN:asin
                  completion:^(NSDictionary *readData, NSError *error) {
                      if (error)
                      {
                          if (completion)
                              completion(NO, error);
                          return;
                      }

                      if (!readData)
                      {

                          [self
                              findUserBookAndEditionForASIN:asin
                                                 completion:^(NSDictionary *bookData,
                                                              NSError      *bookError) {
                                                     if (bookError || !bookData)
                                                     {
                                                         NSError *notFoundError = [NSError
                                                             errorWithDomain:@"HardcoverAPI"
                                                                        code:404
                                                                    userInfo:@{
                                                                        NSLocalizedDescriptionKey :
                                                                            @"Book not found in "
                                                                            @"user's library"
                                                                    }];
                                                         if (completion)
                                                             completion(NO, notFoundError);
                                                         return;
                                                     }

                                                     NSNumber *userBookId = bookData[@"userBookId"];
                                                     NSNumber *editionId  = bookData[@"editionId"];

                                                     [self
                                                         insertUserBookRead:userBookId
                                                            progressSeconds:seconds
                                                                  editionId:editionId
                                                                 completion:^(
                                                                     NSDictionary *newReadData,
                                                                     NSError      *insertError) {
                                                                     if (insertError ||
                                                                         !newReadData)
                                                                     {
                                                                         if (completion)
                                                                             completion(
                                                                                 NO, insertError);
                                                                         return;
                                                                     }

                                                                     self.asinToIDs[asin] = @{
                                                                         @"user_book_id" :
                                                                                 newReadData
                                                                                     [@"userBook"
                                                                                      @"Id"]
                                                                             ?: @0,
                                                                         @"edition_id" : newReadData
                                                                                 [@"editionI"
                                                                                  @"d"]
                                                                             ?: @0,
                                                                         @"audio_seconds" : bookData
                                                                                 [@"audioSec"
                                                                                  @"onds"]
                                                                             ?: @0
                                                                     };

                                                                     if (completion)
                                                                         completion(YES, nil);
                                                                 }];
                                                 }];
                          return;
                      }

                      NSNumber *readId         = readData[@"readId"];
                      NSNumber *foundEditionId = readData[@"editionId"];

                      self.asinToIDs[asin] = @{
                          @"user_book_id" : readData[@"userBookId"] ?: @0,
                          @"edition_id" : foundEditionId,
                          @"audio_seconds" : readData[@"audioSeconds"] ?: @0
                      };

                      NSString *startedAt    = nil;
                      id        startedAtVal = readData[@"startedAt"];
                      if ([startedAtVal isKindOfClass:[NSString class]])
                      {
                          startedAt = startedAtVal;
                      }

                      [self updateExistingReadProgress:readId
                                       progressSeconds:seconds
                                             editionId:foundEditionId
                                             startedAt:startedAt
                                            completion:completion];
                  }];
}

- (void)getLatestReadForASIN:(NSString *)asin
                  completion:(void (^)(NSDictionary *readData, NSError *error))completion
{
    NSString *query = @"query getLatestRead { "
                      @"me { "
                      @"user_books(where: {status_id: {_eq: 2}}, order_by: {updated_at: desc}) { "
                      @"id "
                      @"user_book_reads { "
                      @"id "
                      @"progress_seconds "
                      @"started_at "
                      @"finished_at "
                      @"edition { "
                      @"id "
                      @"asin "
                      @"audio_seconds "
                      @"} "
                      @"} "
                      @"} "
                      @"} "
                      @"}";

    [self makeGraphQLRequest:query
              withCompletion:^(NSDictionary *response, NSError *error) {
                  if (error)
                  {
                      if (completion)
                          completion(nil, error);
                      return;
                  }

                  @try
                  {
                      NSDictionary *data  = response[@"data"];
                      NSArray      *users = data[@"me"];

                      if (!users || users.count == 0)
                      {
                          if (completion)
                              completion(nil, nil);
                          return;
                      }

                      NSDictionary *user      = users.firstObject;
                      NSArray      *userBooks = user[@"user_books"];

                      if (![userBooks isKindOfClass:[NSArray class]] || userBooks.count == 0)
                      {
                          if (completion)
                              completion(nil, nil);
                          return;
                      }

                      for (NSDictionary *userBook in userBooks)
                      {
                          if (![userBook isKindOfClass:[NSDictionary class]])
                              continue;

                          NSArray *reads = userBook[@"user_book_reads"];
                          if (![reads isKindOfClass:[NSArray class]] || reads.count == 0)
                              continue;

                          for (NSInteger i = (NSInteger) reads.count - 1; i >= 0; i--)
                          {
                              NSDictionary *read = reads[i];
                              if (![read isKindOfClass:[NSDictionary class]])
                                  continue;

                              NSDictionary *edition = read[@"edition"];
                              if (![edition isKindOfClass:[NSDictionary class]])
                                  continue;

                              NSString *editionASIN = edition[@"asin"];
                              if (![editionASIN isKindOfClass:[NSString class]])
                                  continue;

                              if ([editionASIN isEqualToString:asin])
                              {
                                  NSDictionary *readData = @{
                                      @"readId" : read[@"id"] ?: @0,
                                      @"userBookId" : userBook[@"id"] ?: @0,
                                      @"editionId" : edition[@"id"] ?: @0,
                                      @"audioSeconds" : edition[@"audio_seconds"] ?: @0,
                                      @"progressSeconds" : read[@"progress_seconds"] ?: @0,
                                      @"startedAt" : read[@"started_at"] ?: [NSNull null],
                                      @"finishedAt" : read[@"finished_at"] ?: [NSNull null]
                                  };

                                  if (completion)
                                      completion(readData, nil);
                                  return;
                              }
                          }
                      }

                      if (completion)
                          completion(nil, nil);
                  }
                  @catch (NSException *exception)
                  {

                      NSError *parseError = [NSError
                          errorWithDomain:@"HardcoverAPI"
                                     code:500
                                 userInfo:@{
                                     NSLocalizedDescriptionKey :
                                         [NSString stringWithFormat:@"Failed to parse response: %@",
                                                                    exception.reason]
                                 }];
                      if (completion)
                          completion(nil, parseError);
                  }
              }];
}

- (void)findUserBookAndEditionForASIN:(NSString *)asin
                           completion:(void (^)(NSDictionary *bookData, NSError *error))completion
{
    NSString *query = [NSString stringWithFormat:@"query FindBookByASIN { "
                                                 @"me { "
                                                 @"user_books { "
                                                 @"id "
                                                 @"book { "
                                                 @"editions(where: {asin: {_eq: \"%@\"}}) { "
                                                 @"id "
                                                 @"asin "
                                                 @"audio_seconds "
                                                 @"} "
                                                 @"} "
                                                 @"} "
                                                 @"} "
                                                 @"}",
                                                 asin];

    [self
        makeGraphQLRequest:query
            withCompletion:^(NSDictionary *response, NSError *error) {
                if (error)
                {

                    if (completion)
                        completion(nil, error);
                    return;
                }

                @try
                {

                    NSDictionary *data = response[@"data"];
                    if (![data isKindOfClass:[NSDictionary class]])
                    {
                        if (completion)
                            completion(nil, [NSError errorWithDomain:@"HardcoverAPI"
                                                                code:500
                                                            userInfo:@{
                                                                NSLocalizedDescriptionKey :
                                                                    @"Invalid response format"
                                                            }]);
                        return;
                    }

                    NSArray *users = data[@"users"];
                    if (![users isKindOfClass:[NSArray class]] || users.count == 0)
                    {
                        if (completion)
                            completion(nil, [NSError errorWithDomain:@"HardcoverAPI"
                                                                code:404
                                                            userInfo:@{
                                                                NSLocalizedDescriptionKey :
                                                                    @"User not found"
                                                            }]);
                        return;
                    }

                    NSDictionary *user      = users[0];
                    NSArray      *userBooks = user[@"user_books"];

                    if (![userBooks isKindOfClass:[NSArray class]])
                    {
                        if (completion)
                            completion(nil, [NSError errorWithDomain:@"HardcoverAPI"
                                                                code:500
                                                            userInfo:@{
                                                                NSLocalizedDescriptionKey :
                                                                    @"Invalid user_books format"
                                                            }]);
                        return;
                    }

                    for (NSDictionary *userBook in userBooks)
                    {
                        if (![userBook isKindOfClass:[NSDictionary class]])
                            continue;

                        NSDictionary *book = userBook[@"book"];
                        if (![book isKindOfClass:[NSDictionary class]])
                            continue;

                        NSArray *editions = book[@"editions"];
                        if (![editions isKindOfClass:[NSArray class]])
                            continue;

                        for (NSDictionary *edition in editions)
                        {
                            if (![edition isKindOfClass:[NSDictionary class]])
                                continue;

                            NSString *editionAsin = edition[@"asin"];
                            if ([editionAsin isEqualToString:asin])
                            {

                                NSDictionary *bookData = @{
                                    @"userBookId" : userBook[@"id"],
                                    @"editionId" : edition[@"id"],
                                    @"audioSeconds" : edition[@"audio_seconds"] ?: @0
                                };

                                if (completion)
                                    completion(bookData, nil);
                                return;
                            }
                        }
                    }

                    if (completion)
                        completion(nil,
                                   [NSError errorWithDomain:@"HardcoverAPI"
                                                       code:404
                                                   userInfo:@{
                                                       NSLocalizedDescriptionKey :
                                                           @"Book with ASIN not found in library"
                                                   }]);
                }
                @catch (NSException *exception)
                {
                    NSError *parseError = [NSError
                        errorWithDomain:@"HardcoverAPI"
                                   code:500
                               userInfo:@{
                                   NSLocalizedDescriptionKey : [NSString
                                       stringWithFormat:@"Failed to parse book search response: %@",
                                                        exception.reason]
                               }];
                    if (completion)
                        completion(nil, parseError);
                }
            }];
}

- (void)insertUserBookRead:(NSNumber *)userBookId
           progressSeconds:(NSInteger)seconds
                 editionId:(NSNumber *)editionId
                completion:(void (^)(NSDictionary *readData, NSError *error))completion
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat       = @"yyyy-MM-dd";
    NSString *startedAt        = [formatter stringFromDate:[NSDate date]];

    NSString *mutation =
        @"mutation InsertUserBookRead($userBookId: Int!, $object: DatesReadInput!) { "
        @"insert_user_book_read(user_book_id: $userBookId, user_book_read: $object) { "
        @"error "
        @"user_book_read { "
        @"id "
        @"user_book_id "
        @"progress_seconds "
        @"edition_id "
        @"started_at "
        @"finished_at "
        @"} "
        @"} "
        @"}";

    NSDictionary *readObject = @{
        @"progress_seconds" : @(seconds),
        @"progress_pages" : @0,
        @"edition_id" : editionId,
        @"started_at" : startedAt,
        @"finished_at" : [NSNull null],
        @"reading_format_id" : @2
    };

    NSDictionary *variables = @{@"userBookId" : userBookId, @"object" : readObject};

    [self makeGraphQLRequestWithQuery:mutation
                            variables:variables
                           completion:^(NSDictionary *response, NSError *error) {
                               if (error)
                               {
                                   if (completion)
                                       completion(nil, error);
                                   return;
                               }

                               @try
                               {
                                   NSDictionary *data         = response[@"data"];
                                   NSDictionary *insertResult = data[@"insert_user_book_read"];

                                   if (insertResult && !insertResult[@"error"])
                                   {
                                       NSDictionary *newRead = insertResult[@"user_book_read"];
                                       if (newRead)
                                       {
                                           NSDictionary *readData = @{
                                               @"readId" : newRead[@"id"],
                                               @"userBookId" : newRead[@"user_book_id"],
                                               @"editionId" : newRead[@"edition_id"]
                                           };

                                           if (completion)
                                               completion(readData, nil);
                                       }
                                       else
                                       {
                                           NSError *insertError = [NSError
                                               errorWithDomain:@"HardcoverAPI"
                                                          code:500
                                                      userInfo:@{
                                                          NSLocalizedDescriptionKey :
                                                              @"No read data returned from insert"
                                                      }];
                                           if (completion)
                                               completion(nil, insertError);
                                       }
                                   }
                                   else
                                   {
                                       NSString *errorMsg =
                                           insertResult[@"error"] ?: @"Insert failed";
                                       NSError *insertError = [NSError
                                           errorWithDomain:@"HardcoverAPI"
                                                      code:500
                                                  userInfo:@{NSLocalizedDescriptionKey : errorMsg}];
                                       if (completion)
                                           completion(nil, insertError);
                                   }
                               }
                               @catch (NSException *exception)
                               {
                                   NSError *parseError = [NSError
                                       errorWithDomain:@"HardcoverAPI"
                                                  code:500
                                              userInfo:@{
                                                  NSLocalizedDescriptionKey : [NSString
                                                      stringWithFormat:
                                                          @"Failed to parse insert response: %@",
                                                          exception.reason]
                                              }];
                                   if (completion)
                                       completion(nil, parseError);
                               }
                           }];
}

- (void)updateExistingReadProgress:(NSNumber *)readId
                   progressSeconds:(NSInteger)seconds
                         editionId:(NSNumber *)editionId
                         startedAt:(NSString *_Nullable)startedAt
                        completion:(void (^)(BOOL success, NSError *error))completion
{
    NSString *mutation = @"mutation UpdateBookProgress($id: Int!, $object: DatesReadInput!) { "
                         @"update_user_book_read(id: $id, object: $object) { "
                         @"error "
                         @"user_book_read { "
                         @"id "
                         @"progress "
                         @"progress_seconds "
                         @"progress_pages "
                         @"edition_id "
                         @"started_at "
                         @"finished_at "
                         @"} "
                         @"} "
                         @"}";

    NSMutableDictionary *updateObject = [@{
        @"progress_seconds" : @(seconds),
        @"progress_pages" : @0,
        @"edition_id" : editionId,
        @"finished_at" : [NSNull null]
    } mutableCopy];
    if ([startedAt isKindOfClass:[NSString class]] && startedAt.length > 0)
    {
        updateObject[@"started_at"] = startedAt;
    }
    NSDictionary *variables = @{@"id" : readId, @"object" : updateObject};

    [self makeGraphQLRequestWithQuery:mutation
                            variables:variables
                           completion:^(NSDictionary *response, NSError *error) {
                               if (error)
                               {
                                   if (completion)
                                       completion(NO, error);
                                   return;
                               }

                               @try
                               {
                                   NSDictionary *data         = response[@"data"];
                                   NSDictionary *updateResult = data[@"update_user_book_read"];

                                   if (updateResult)
                                   {
                                       id errorValue = updateResult[@"error"];

                                       BOOL hasError =
                                           (errorValue && ![errorValue isEqual:[NSNull null]]);

                                       if (hasError)
                                       {
                                       }

                                       if (!hasError)
                                       {
                                           NSDictionary *updatedRead =
                                               updateResult[@"user_book_read"];
                                           if (updatedRead)
                                           {
                                               if (completion)
                                                   completion(YES, nil);
                                           }
                                           else
                                           {
                                               NSError *updateError =
                                                   [NSError errorWithDomain:@"HardcoverAPI"
                                                                       code:500
                                                                   userInfo:@{
                                                                       NSLocalizedDescriptionKey :
                                                                           @"No read data returned"
                                                                   }];
                                               if (completion)
                                                   completion(NO, updateError);
                                           }
                                       }
                                       else
                                       {
                                           NSString *errorMsg =
                                               [NSString stringWithFormat:@"%@", errorValue];
                                           NSError *updateError = [NSError
                                               errorWithDomain:@"HardcoverAPI"
                                                          code:500
                                                      userInfo:@{
                                                          NSLocalizedDescriptionKey : errorMsg
                                                      }];
                                           if (completion)
                                               completion(NO, updateError);
                                       }
                                   }
                                   else
                                   {
                                       NSError *updateError =
                                           [NSError errorWithDomain:@"HardcoverAPI"
                                                               code:500
                                                           userInfo:@{
                                                               NSLocalizedDescriptionKey :
                                                                   @"No update result returned"
                                                           }];
                                       if (completion)
                                           completion(NO, updateError);
                                   }
                               }
                               @catch (NSException *exception)
                               {
                                   NSError *parseError =
                                       [NSError errorWithDomain:@"HardcoverAPI"
                                                           code:500
                                                       userInfo:@{
                                                           NSLocalizedDescriptionKey :
                                                               @"Failed to parse update response"
                                                       }];
                                   if (completion)
                                       completion(NO, parseError);
                               }
                           }];
}

- (void)markBookCompletedForASIN:(NSString *)asin
                    totalSeconds:(NSInteger)totalSeconds
                      completion:
                          (void (^_Nullable)(BOOL success, NSError *_Nullable error))completion
{

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat       = @"yyyy-MM-dd";
    NSString *finishedAt       = [formatter stringFromDate:[NSDate date]];

    [self getLatestReadForASIN:asin
                    completion:^(NSDictionary *readData, NSError *error) {
                        if (error || !readData)
                        {
                            if (completion)
                                completion(NO, error);
                            return;
                        }

                        NSNumber *readId    = readData[@"readId"];
                        NSNumber *editionId = readData[@"editionId"];

                        NSString *mutation = @"mutation MarkBookCompleted($id: Int!, $seconds: "
                                             @"Int!, $editionId: Int!, $finishedAt: date!) { "
                                             @"update_user_book_read(id: $id, object: { "
                                             @"progress_seconds: $seconds, "
                                             @"edition_id: $editionId, "
                                             @"finished_at: $finishedAt "
                                             @"}) { "
                                             @"error "
                                             @"user_book_read { "
                                             @"id "
                                             @"progress_seconds "
                                             @"finished_at "
                                             @"started_at "
                                             @"edition_id "
                                             @"} "
                                             @"} "
                                             @"}";

                        NSDictionary *variables = @{
                            @"id" : readId,
                            @"seconds" : @(totalSeconds),
                            @"editionId" : editionId,
                            @"finishedAt" : finishedAt
                        };

                        [self
                            makeGraphQLRequestWithQuery:mutation
                                              variables:variables
                                             completion:^(NSDictionary *response, NSError *error) {
                                                 if (error)
                                                 {
                                                     if (completion)
                                                         completion(NO, error);
                                                     return;
                                                 }

                                                 @try
                                                 {
                                                     NSDictionary *data = response[@"data"];
                                                     NSDictionary *updateResult =
                                                         data[@"update_user_book_read"];

                                                     if (updateResult[@"error"] &&
                                                         ![updateResult[@"error"]
                                                             isKindOfClass:[NSNull class]])
                                                     {
                                                         NSString *errorMsg =
                                                             updateResult[@"error"];
                                                         NSError *updateError = [NSError
                                                             errorWithDomain:@"HardcoverAPI"
                                                                        code:400
                                                                    userInfo:@{
                                                                        NSLocalizedDescriptionKey :
                                                                            errorMsg
                                                                    }];
                                                         if (completion)
                                                             completion(NO, updateError);
                                                         return;
                                                     }

                                                     NSDictionary *completedRead =
                                                         updateResult[@"user_book_read"];
                                                     if (completedRead)
                                                     {
                                                         if (completion)
                                                             completion(YES, nil);
                                                     }
                                                     else
                                                     {
                                                         NSError *updateError = [NSError
                                                             errorWithDomain:@"HardcoverAPI"
                                                                        code:500
                                                                    userInfo:@{
                                                                        NSLocalizedDescriptionKey :
                                                                            @"No completion "
                                                                            @"data "
                                                                            @"returned"
                                                                    }];
                                                         if (completion)
                                                             completion(NO, updateError);
                                                     }
                                                 }
                                                 @catch (NSException *exception)
                                                 {
                                                     NSError *parseError = [NSError
                                                         errorWithDomain:@"HardcoverAPI"
                                                                    code:500
                                                                userInfo:@{
                                                                    NSLocalizedDescriptionKey :
                                                                        @"Failed to parse "
                                                                        @"completion response"
                                                                }];
                                                     if (completion)
                                                         completion(NO, parseError);
                                                 }
                                             }];
                    }];
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

- (void)createEditionForBook:(NSNumber *)bookId
                       title:(NSString *)title
              contributorIds:(NSArray<NSNumber *> *)contributorIds
                        asin:(NSString *)asin
                audioSeconds:(NSInteger)audioSeconds
                  completion:(void (^)(NSNumber *editionId, NSError *error))completion
{
    if (!self.apiToken || self.apiToken.length == 0)
    {
        NSError *error = [NSError errorWithDomain:@"HardcoverAPI"
                                             code:401
                                         userInfo:@{NSLocalizedDescriptionKey : @"No API token"}];
        if (completion)
            completion(nil, error);
        return;
    }

    NSMutableArray *contributions = [NSMutableArray array];
    for (NSNumber *authorId in contributorIds)
    {
        [contributions addObject:@{@"author_id" : authorId, @"contribution" : [NSNull null]}];
    }

    NSString *mutation =
        @"mutation CreateEdition($bookId: Int!, $edition: EditionInput!) {\n"
        @"  createResponse: insert_edition(book_id: $bookId, edition: $edition) {\n"
        @"    errors\n"
        @"    edition {\n"
        @"      id\n"
        @"      book {\n"
        @"        slug\n"
        @"        __typename\n"
        @"      }\n"
        @"      __typename\n"
        @"    }\n"
        @"    __typename\n"
        @"  }\n"
        @"}";

    NSDictionary *editionDto = @{
        @"title" : title,
        @"contributions" : contributions,
        @"language_id" : @1,
        @"country_id" : @1,
        @"reading_format_id" : @2,
        @"audio_seconds" : @(audioSeconds),
        @"asin" : asin
    };

    NSDictionary *editionObject = @{@"book_id" : bookId, @"dto" : editionDto};

    NSDictionary *variables = @{@"bookId" : bookId, @"edition" : editionObject};

    [self makeGraphQLRequestWithQuery:mutation
                            variables:variables
                           completion:^(NSDictionary *response, NSError *error) {
                               if (error)
                               {
                                   if (completion)
                                       completion(nil, error);
                                   return;
                               }

                               NSDictionary *data           = response[@"data"];
                               NSDictionary *createResponse = data[@"createResponse"];
                               NSArray      *errors         = createResponse[@"errors"];

                               if (errors && ![errors isKindOfClass:[NSNull class]] &&
                                   [errors isKindOfClass:[NSArray class]] && errors.count > 0)
                               {
                                   NSString *errorMsg = [errors componentsJoinedByString:@", "];
                                   NSError  *apiError = [NSError
                                       errorWithDomain:@"HardcoverAPI"
                                                  code:400
                                              userInfo:@{NSLocalizedDescriptionKey : errorMsg}];
                                   if (completion)
                                       completion(nil, apiError);
                                   return;
                               }

                               NSDictionary *edition   = createResponse[@"edition"];
                               NSNumber     *editionId = edition[@"id"];

                               if (completion)
                                   completion(editionId, nil);
                           }];
}

- (void)switchUserBookToEdition:(NSNumber *)userBookId
                      editionId:(NSNumber *)editionId
                     completion:(void (^)(BOOL success, NSError *error))completion
{
    if (!self.apiToken || self.apiToken.length == 0)
    {
        NSError *error = [NSError errorWithDomain:@"HardcoverAPI"
                                             code:401
                                         userInfo:@{NSLocalizedDescriptionKey : @"No API token"}];
        if (completion)
            completion(NO, error);
        return;
    }

    NSString *mutation = @"mutation UpdateUserBook($id: Int!, $object: UserBookUpdateInput!) {\n"
                         @"  updateResponse: update_user_book(id: $id, object: $object) {\n"
                         @"    error\n"
                         @"    userBook: user_book {\n"
                         @"      id\n"
                         @"      editionId: edition_id\n"
                         @"      __typename\n"
                         @"    }\n"
                         @"    __typename\n"
                         @"  }\n"
                         @"}";

    NSDictionary *updateObject = @{
        @"edition_id" : editionId,
        @"status_id" : @2,
        @"rating" : [NSNull null],
        @"privacy_setting_id" : @1
    };

    NSDictionary *variables = @{@"id" : userBookId, @"object" : updateObject};

    [self makeGraphQLRequestWithQuery:mutation
                            variables:variables
                           completion:^(NSDictionary *response, NSError *error) {
                               if (error)
                               {
                                   if (completion)
                                       completion(NO, error);
                                   return;
                               }

                               NSDictionary *data           = response[@"data"];
                               NSDictionary *updateResponse = data[@"updateResponse"];
                               NSString     *errorMsg       = updateResponse[@"error"];

                               if (errorMsg && ![errorMsg isKindOfClass:[NSNull class]])
                               {
                                   NSError *apiError = [NSError
                                       errorWithDomain:@"HardcoverAPI"
                                                  code:400
                                              userInfo:@{NSLocalizedDescriptionKey : errorMsg}];
                                   if (completion)
                                       completion(NO, apiError);
                                   return;
                               }

                               if (completion)
                                   completion(YES, nil);
                           }];
}

- (void)findEditionByASIN:(NSString *)asin
               completion:(void (^)(NSNumber *editionId, NSError *error))completion
{
    if (!self.apiToken || self.apiToken.length == 0)
    {
        NSError *error =
            [NSError errorWithDomain:@"HardcoverAPI"
                                code:401
                            userInfo:@{NSLocalizedDescriptionKey : @"No API token provided"}];
        if (completion)
            completion(nil, error);
        return;
    }

    NSString *query =
        [NSString stringWithFormat:@"query FindEditionByASIN {\n"
                                   @"  editions(where: {asin: {_eq: \"%@\"}}, limit: 1) {\n"
                                   @"    id\n"
                                   @"    asin\n"
                                   @"  }\n"
                                   @"}",
                                   asin];

    [self makeGraphQLRequest:query
              withCompletion:^(NSDictionary *response, NSError *error) {
                  if (error)
                  {
                      if (completion)
                          completion(nil, error);
                      return;
                  }

                  @try
                  {
                      NSDictionary *data     = response[@"data"];
                      NSArray      *editions = data[@"editions"];

                      if (![editions isKindOfClass:[NSArray class]] || editions.count == 0)
                      {
                          if (completion)
                              completion(nil, nil);
                          return;
                      }

                      NSDictionary *edition   = editions.firstObject;
                      NSNumber     *editionId = edition[@"id"];

                      if ([editionId isKindOfClass:[NSNumber class]])
                      {
                          if (completion)
                              completion(editionId, nil);
                      }
                      else
                      {
                          if (completion)
                              completion(nil, nil);
                      }
                  }
                  @catch (NSException *exception)
                  {
                      NSError *parseError = [NSError
                          errorWithDomain:@"HardcoverAPI"
                                     code:500
                                 userInfo:@{
                                     NSLocalizedDescriptionKey : @"Failed to parse edition response"
                                 }];
                      if (completion)
                          completion(nil, parseError);
                  }
              }];
}

- (void)fetchEditionsForBookId:(NSNumber *)bookId
                    completion:(void (^)(NSArray *editions, NSError *error))completion
{
    if (!bookId || !completion)
    {
        if (completion)
            completion(nil,
                       [NSError
                           errorWithDomain:@"HardcoverAPI"
                                      code:400
                                  userInfo:@{NSLocalizedDescriptionKey : @"Invalid parameters"}]);
        return;
    }

    NSString *query = [NSString stringWithFormat:@"query GetBookEditions {\n"
                                                 @"  books(where: {id: {_eq: %@}}, limit: 1) {\n"
                                                 @"    editions {\n"
                                                 @"      id\n"
                                                 @"      asin\n"
                                                 @"    }\n"
                                                 @"  }\n"
                                                 @"}",
                                                 bookId];

    [self
        makeGraphQLRequest:query
            withCompletion:^(NSDictionary *response, NSError *error) {
                if (error)
                {
                    completion(nil, error);
                    return;
                }

                @try
                {
                    NSDictionary *data  = response[@"data"];
                    NSArray      *books = data[@"books"];

                    if (![books isKindOfClass:[NSArray class]] || books.count == 0)
                    {
                        completion(@[], nil);
                        return;
                    }

                    NSDictionary *book     = books.firstObject;
                    NSArray      *editions = book[@"editions"];

                    if (![editions isKindOfClass:[NSArray class]])
                    {
                        completion(@[], nil);
                        return;
                    }

                    completion(editions, nil);
                }
                @catch (NSException *exception)
                {
                    completion(
                        nil,
                        [NSError errorWithDomain:@"HardcoverAPI"
                                            code:500
                                        userInfo:@{NSLocalizedDescriptionKey : exception.reason}]);
                }
            }];
}

+ (void)autoSwitchToEditionForASIN:(NSString *)asin
{
    if (!asin || asin.length == 0)
        return;

    HardcoverAPI *api = [HardcoverAPI sharedInstance];
    if (!api.apiToken || api.apiToken.length == 0)
        return;

    if (!api.isAuthorized || !api.currentUser)
    {
        [api authorizeWithCompletion:^(BOOL success, HardcoverUser *user, NSError *error) {
            if (success && user)
            {
                [HardcoverAPI autoSwitchToEditionForASIN:asin];
            }
        }];
        return;
    }

    [api refreshUserWithCompletion:^(BOOL success, HardcoverUser *user, NSError *userError) {
        if (!success || !user || !user.userId)
            return;

        [api
            fetchCurrentlyReadingForUserId:user.userId
                                completion:^(NSArray *items, NSError *crError) {
                                    if (crError || !items || items.count == 0)
                                        return;

                                    __block BOOL foundMatch = NO;

                                    for (NSDictionary *item in items)
                                    {
                                        NSNumber *bookId     = item[@"bookId"];
                                        NSNumber *userBookId = item[@"user_book_id"];

                                        if (!bookId || !userBookId)
                                            continue;

                                        [api
                                            fetchEditionsForBookId:bookId
                                                        completion:^(NSArray *editions,
                                                                     NSError *editionError) {
                                                            if (foundMatch)
                                                                return;

                                                            if (editionError || !editions ||
                                                                editions.count == 0)
                                                                return;

                                                            NSNumber *targetEditionId = nil;
                                                            for (NSDictionary *edition in editions)
                                                            {
                                                                NSString *editionASIN =
                                                                    edition[@"asin"];
                                                                if ([editionASIN
                                                                        isKindOfClass:[NSString
                                                                                          class]] &&
                                                                    [editionASIN
                                                                        isEqualToString:asin])
                                                                {
                                                                    targetEditionId =
                                                                        edition[@"id"];
                                                                    break;
                                                                }
                                                            }

                                                            if (targetEditionId)
                                                            {
                                                                foundMatch = YES;

                                                                NSArray *currentReads =
                                                                    item[@"user_book_reads"];
                                                                BOOL alreadyOnCorrectEdition = NO;

                                                                if ([currentReads
                                                                        isKindOfClass:[NSArray
                                                                                          class]] &&
                                                                    currentReads.count > 0)
                                                                {
                                                                    for (NSDictionary
                                                                             *read in currentReads)
                                                                    {
                                                                        NSDictionary *edition =
                                                                            read[@"edition"];
                                                                        if ([edition
                                                                                isKindOfClass:
                                                                                    [NSDictionary
                                                                                        class]])
                                                                        {
                                                                            NSNumber
                                                                                *currentEditionId =
                                                                                    edition[@"id"];
                                                                            if ([currentEditionId
                                                                                    isEqual:
                                                                                        targetEditionId])
                                                                            {
                                                                                alreadyOnCorrectEdition =
                                                                                    YES;
                                                                                break;
                                                                            }
                                                                        }
                                                                    }
                                                                }

                                                                if (!alreadyOnCorrectEdition)
                                                                {
                                                                    [api
                                                                        performSilentEditionSwitch:
                                                                            targetEditionId
                                                                                       forUserBook:
                                                                                           userBookId
                                                                                          withASIN:
                                                                                              asin];
                                                                }
                                                            }
                                                        }];
                                    }
                                }];
    }];
}

- (void)performSilentEditionSwitch:(NSNumber *)editionId
                       forUserBook:(NSNumber *)userBookId
                          withASIN:(NSString *)asin
{
    [self switchUserBookToEdition:userBookId
                        editionId:editionId
                       completion:^(BOOL success, NSError *error) {
                           if (error || !success)
                           {
                               [Logger error:LOG_CATEGORY_DEFAULT
                                      format:@"Edition switch failed: %@",
                                             error.localizedDescription ?: @"Unknown error"];
                               return;
                           }

                           NSInteger currentProgress = 0;
                           if (asin && asin.length > 0)
                           {
                               currentProgress =
                                   [AudibleMetadataCapture getCurrentProgressForASIN:asin];
                           }

                           [self insertUserBookRead:userBookId
                                    progressSeconds:currentProgress
                                          editionId:editionId
                                         completion:^(NSDictionary *readData, NSError *readError) {
                                             dispatch_async(dispatch_get_main_queue(), ^{
                                                 [[NSNotificationCenter defaultCenter]
                                                     postNotificationName:@"AutoSwitchCompleted"
                                                                   object:nil];
                                             });
                                         }];
                       }];
}

@end
