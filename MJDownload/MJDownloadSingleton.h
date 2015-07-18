
#define MJSingletonH + (instancetype)sharedInstance;

#define MJSingletonM(block) \
- (instancetype)init { \
    __block typeof(self) tempSelf; \
    static dispatch_once_t onceToken; \
    dispatch_once(&onceToken, ^{ \
        tempSelf = [super init]; \
    }); \
    if (tempSelf) { \
        self = tempSelf; \
        static dispatch_once_t onceToken; \
        dispatch_once(&onceToken, block); \
    } \
    return self; \
} \
 \
static id _instance = nil; \
+ (instancetype)allocWithZone:(struct _NSZone *)zone \
{ \
    static dispatch_once_t onceToken; \
    dispatch_once(&onceToken, ^{ \
        _instance = [super allocWithZone:zone]; \
    }); \
    return _instance; \
} \
 \
+ (instancetype)sharedInstance \
{ \
    static dispatch_once_t onceToken; \
    dispatch_once(&onceToken, ^{ \
        _instance = [[self alloc] init]; \
    }); \
    return _instance; \
} \
 \
- (id)copyWithZone:(NSZone *)zone \
{ \
    return _instance; \
}