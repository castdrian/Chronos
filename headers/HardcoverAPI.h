#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HardcoverUser : NSObject
@property (nonatomic, strong, nullable) NSNumber *userId;
@property (nonatomic, strong, nullable) NSString *username;
@property (nonatomic, strong, nullable) NSString *name;
@property (nonatomic, strong, nullable) NSString *imageURL;
@property (nonatomic, strong, nullable) NSString *birthdate;
@property (nonatomic, strong, nullable) NSString *flair;
@property (nonatomic, strong, nullable) NSString *location;
@property (nonatomic, strong, nullable) NSString *pronoun_personal;
@property (nonatomic, strong, nullable) NSString *pronoun_possessive;
@property (nonatomic, strong, nullable) NSNumber *books_count;
@property (nonatomic, strong, nullable) NSNumber *followers_count;
@property (nonatomic, strong, nullable) NSNumber *followed_users_count;
@property (nonatomic, strong, nullable) NSNumber *sign_in_count;
@property (nonatomic, assign) BOOL pro;
@end

@interface HardcoverAPI : NSObject

+ (nonnull instancetype)sharedInstance;

@property (nonatomic, strong, nullable) NSString *apiToken;
@property (nonatomic, strong, nullable) HardcoverUser *currentUser;
@property (nonatomic, assign) BOOL isAuthorized;

- (void)setAPIToken:(nullable NSString *)token;
- (void)authorizeWithCompletion:(void (^ _Nullable)(BOOL success, HardcoverUser * _Nullable user, NSError * _Nullable error))completion;
- (void)refreshUserWithCompletion:(void (^ _Nullable)(BOOL success, HardcoverUser * _Nullable user, NSError * _Nullable error))completion;
- (void)saveToken:(nullable NSString *)token;
- (nullable NSString *)loadSavedToken;
- (void)clearToken;

@end

NS_ASSUME_NONNULL_END
