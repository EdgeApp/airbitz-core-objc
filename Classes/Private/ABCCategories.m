//
//  ABCCategories.m
//  Airbitz
//

#import "ABCCategories+Internal.h"
#import "AirbitzCore+Internal.h"

@interface ABCCategories ()
{
    ABCAccount          *_account;
    NSArray             *_categoryList;
    BOOL                _categoriesUpdated;
}

@end

@implementation ABCCategories

- (id) initWithAccount:(ABCAccount *)account;
{
    _account = account;
    return self;
}

- (NSArray *)listCategories
{
    if (_categoryList && !_categoriesUpdated)
        return _categoryList;

    _categoriesUpdated = NO;
    char            **aszCategories = NULL;
    unsigned int    countCategories = 0;
    NSMutableArray *mutableArrayCategories = [[NSMutableArray alloc] init];
    
    // get the categories from the core
    tABC_Error error;
    ABC_GetCategories([_account.name UTF8String],
                      [_account.password UTF8String],
                      &aszCategories,
                      &countCategories,
                      &error);
    
    // If we've never added any categories, add them now
    if (countCategories == 0)
    {
        NSMutableArray *arrayCategories = [[NSMutableArray alloc] init];
        //
        // Expense categories
        //
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Air Travel", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Alcohol & Bars", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Allowance", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Amusement", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Arts", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"ATM Fee", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Auto & Transport", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Auto Insurance", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Auto Payment", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Baby Supplies", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Babysitter & Daycare", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Bank Fee", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Bills & Utilities", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Books", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Books & Supplies", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Car Wash", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Cash & ATM", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Charity", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Clothing", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Coffee Shops", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Credit Card Payment", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Dentist", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Deposit to Savings", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Doctor", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Education", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Electronics & Software", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Entertainment", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Eyecare", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Fast Food", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Fees & Charges", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Financial", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Financial Advisor", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Food & Dining", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Furnishings", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Gas & Fuel", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Gift", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Gifts & Donations", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Groceries", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Gym", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Hair", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Health & Fitness", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"HOA Dues", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Hobbies", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Home", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Home Improvement", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Home Insurance", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Home Phone", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Home Services", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Home Supplies", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Hotel", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Interest Exp", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Internet", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"IRA Contribution", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Kids", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Kids Activities", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Late Fee", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Laundry", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Lawn & Garden", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Life Insurance", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Misc.", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Mobile Phone", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Mortgage & Rent", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Mortgage Interest", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Movies & DVDs", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Music", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Newspaper & Magazines", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Not Sure", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Parking", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Personal Care", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Pet Food & Supplies", @"expense category")]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Pet Grooming", @"expense category")]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Pets", @"expense category")]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Pharmacy", @"expense category")]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Property", @"expense category")]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Public Transportation", @"expense category")]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Registration", @"expense category")]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Rental Car & Taxi", @"expense category")]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Restaurants", @"expense category")]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Service & Parts", @"expense category")]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Service Fee", @"expense category")]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Shopping", @"expense category")]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Spa & Massage", @"expense category")]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Sporting Goods", @"expense category")]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Sports", @"expense category")]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Student Loan", @"expense category")]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Tax", @"expense category")]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Television", @"expense category")]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Tolls", @"expense category")]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Toys", @"expense category")]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Trade Commissions", @"expense category")]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Travel", @"expense category")]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Tuition", @"expense category")]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Utilities", @"expense category")]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Vacation", @"expense category")]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExpenseCategory, NSLocalizedString(@"Vet", @"expense category")]];
        
        //
        // Income categories
        //
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringIncomeCategory, NSLocalizedString(@"Consulting Income", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringIncomeCategory, NSLocalizedString(@"Div Income", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringIncomeCategory, NSLocalizedString(@"Net Salary", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringIncomeCategory, NSLocalizedString(@"Other Income", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringIncomeCategory, NSLocalizedString(@"Rent", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringIncomeCategory, NSLocalizedString(@"Sales", nil)]];

        //
        // Exchange Categories
        //
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExchangeCategory, NSLocalizedString(@"Buy Bitcoin", nil)]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringExchangeCategory, NSLocalizedString(@"Sell Bitcoin", nil)]];

        //
        // Transfer Categories
        //
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringTransferCategory, @"Bitcoin.de"]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringTransferCategory, @"Bitfinex"]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringTransferCategory, @"Bitstamp"]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringTransferCategory, @"BTC-e"]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringTransferCategory, @"BTCChina"]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringTransferCategory, @"Bter"]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringTransferCategory, @"Quadriga"]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringTransferCategory, @"Taurus"]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringTransferCategory, @"Coinbase"]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringTransferCategory, @"Huobi"]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringTransferCategory, @"Kraken"]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringTransferCategory, @"MintPal"]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@",abcStringTransferCategory, @"OKCoin"]];

        //
        // Transfer to Wallet Categories
        //
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@:%@",abcStringTransferCategory,abcStringWalletSubCategory, @"Airbitz"]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@:%@",abcStringTransferCategory,abcStringWalletSubCategory, @"Bitcoin Core"]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@:%@",abcStringTransferCategory,abcStringWalletSubCategory, @"Blockchain"]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@:%@",abcStringTransferCategory,abcStringWalletSubCategory, @"Electrum"]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@:%@",abcStringTransferCategory,abcStringWalletSubCategory, @"Multibit"]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@:%@",abcStringTransferCategory,abcStringWalletSubCategory, @"Mycelium"]];
        [arrayCategories addObject:[NSString stringWithFormat:@"%@:%@:%@",abcStringTransferCategory,abcStringWalletSubCategory, @"Dark Wallet"]];

        // add default categories to core
        for (int i = 0; i < [arrayCategories count]; i++)
        {
            NSString *strCategory = [arrayCategories objectAtIndex:i];
            [mutableArrayCategories addObject:strCategory];
            
            ABC_AddCategory([_account.name UTF8String],
                            [_account.password UTF8String],
                            (char *)[strCategory UTF8String], &error);
        }
    }
    else
    {
        // store them in our own array
        
        if (aszCategories && countCategories > 0)
        {
            for (int i = 0; i < countCategories; i++)
            {
                [mutableArrayCategories addObject:[NSString stringWithUTF8String:aszCategories[i]]];
            }
        }
        
    }
    
    // free the core categories
    if (aszCategories != NULL)
    {
        [ABCUtil freeStringArray:aszCategories count:countCategories];
    }
    
    NSArray *tempArray = [mutableArrayCategories sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    // store the final as storted
    _categoryList = tempArray;
    
    return _categoryList;
}

- (NSError *)addCategory:(NSString *)category;
{
    NSError *nserror = nil;
    // check and see that it doesn't already exist
    if ([_categoryList indexOfObject:category] == NSNotFound)
    {
        // add the category to the core
        tABC_Error error;
        ABC_AddCategory([_account.name UTF8String],
                        [_account.password UTF8String],
                        (char *)[category UTF8String], &error);
        nserror = [ABCError makeNSError:error];
        _categoriesUpdated = YES;
    }
    return nserror;
}

- (NSError *)removeCategory:(NSString *)category;
{
    tABC_Error error;
    NSError *nserror = nil;
    ABC_RemoveCategory([_account.name UTF8String],
                       [_account.password UTF8String],
                       (char *)[category UTF8String], &error);
    nserror = [ABCError makeNSError:error];
    _categoriesUpdated = YES;
    return nserror;
}

// saves the categories to the core
- (NSError *)saveCategories:(NSArray *)arrayCategories;
{
    NSError *nserror = nil;
    NSError *nserrorRet = nil;
    NSMutableArray *saveArrayCategories = [NSMutableArray arrayWithArray:arrayCategories];
    
    // got through the existing categories
    for (NSString *strCategory in _categoryList)
    {
        // if this category is in our new list
        if ([saveArrayCategories containsObject:strCategory])
        {
            // remove it from our new list since it is already there
            [saveArrayCategories removeObject:strCategory];
        }
        else
        {
            // it doesn't exist in our new list so delete it from the core
            nserror = [self removeCategory:strCategory];
            if (nserror) nserrorRet = nserror;
        }
    }
    
    // add any categories from our new list that didn't exist in the core list
    for (NSString *strCategory in saveArrayCategories)
    {
        nserror = [self addCategory:strCategory];
        if (nserror) nserrorRet = nserror;
    }
    
    return nserrorRet;
}



@end