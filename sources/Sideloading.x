#import "Sideloading.h"

%hook INVocabulary
- (void)_THROW_EXCEPTION_FOR_PROCESS_MISSING_ENTITLEMENT_com_apple_developer_siri {}
%end

%ctor
{
    if (![Utilities hasAudibleProductionEntitlements])
    {
        %init();
    }
}
