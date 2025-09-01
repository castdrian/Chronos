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

    [self makeGraphQLRequest:@"query User { me { id username name image { url } } }"
              withCompletion:^(NSDictionary *response, NSError *error) {
                  if (error)
                  {
                      self.isAuthorized = NO;
                      self.currentUser  = nil;
                      if (completion)
                          completion(NO, nil, error);
                      return;
                  }

                  NSDictionary *data    = response[@"data"];
                  NSArray      *meArray = data[@"me"];

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

                  NSDictionary  *userDict = meArray[0];
                  HardcoverUser *user     = [[HardcoverUser alloc] init];
                  user.userId             = userDict[@"id"];
                  user.username           = userDict[@"username"];
                  user.name               = userDict[@"name"];
                  user.imageURL           = userDict[@"image"][@"url"];

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

- (void)makeGraphQLRequest:(NSString *)query
            withCompletion:(void (^)(NSDictionary *response, NSError *error))completion
{
    NSURL               *url     = [NSURL URLWithString:@"https://api.hardcover.app/v1/graphql"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:_apiToken forHTTPHeaderField:@"Authorization"];

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
