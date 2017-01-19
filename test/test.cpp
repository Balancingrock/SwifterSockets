/*
 *  test.cpp
 *  test
 *
 *  Created by Marinus van der Lugt on 18/01/17.
 *  Copyright © 2017 Marinus van der Lugt. All rights reserved.
 *
 */

#include <iostream>
#include "test.hpp"
#include "testPriv.hpp"

void test::HelloWorld(const char * s)
{
    testPriv *theObj = new testPriv;
    theObj->HelloWorldPriv(s);
    delete theObj;
};

void testPriv::HelloWorldPriv(const char * s) 
{
    std::cout << s << std::endl;
};

