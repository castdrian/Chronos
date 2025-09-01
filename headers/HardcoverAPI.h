#import <Foundation/Foundation.h>

@interface HardcoverUser : NSObject
@property (nonatomic, strong) NSNumber *userId;
@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *imageURL;
@end

@interface HardcoverAPI : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic, strong) NSString *apiToken;
@property (nonatomic, strong) HardcoverUser *currentUser;
@property (nonatomic, assign) BOOL isAuthorized;

- (void)setAPIToken:(NSString *)token;
- (void)authorizeWithCompletion:(void (^)(BOOL success, HardcoverUser *user, NSError *error))completion;
- (void)refreshUserWithCompletion:(void (^)(BOOL success, HardcoverUser *user, NSError *error))completion;
- (void)saveToken:(NSString *)token;
- (NSString *)loadSavedToken;
- (void)clearToken;

@end
