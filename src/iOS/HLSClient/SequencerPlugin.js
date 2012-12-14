// ----------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// ----------------------------------------------------------------------------
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//
// THIS CODE IS PROVIDED *AS IS* BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR IMPLIED,
// INCLUDING WITHOUT LIMITATION ANY IMPLIED WARRANTIES OR CONDITIONS OF TITLE,
// FITNESS FOR A PARTICULAR PURPOSE, MERCHANTABLITY OR NON-INFRINGEMENT.
//

// This file contains the empty implementation for a Sequencer plugin. The app developer can fill in the implemenation
// and add more sequencer plugins in this file.

//
// The namespace object
//
var PLAYER_SEQUENCER = PLAYER_SEQUENCER || {};

PLAYER_SEQUENCER.createCustomSequencerPlugin = function (customPlugin) {
    "use strict";
    
    // Replace the default pass-through methods
    
    // This is a sample code to throw exception in manifestToSeekbarTime to test
    // if the plugin is successfully created. Please remove this or replace this with real implementation
    // if you want to implement a custom sequencer plugin
//    customPlugin.manifestToSeekbarTime = function ( params ) {
//        throw new PLAYER_SEQUENCER.SequencerError('If you see this the plugin is correctly added to the project');
//    };
};

PLAYER_SEQUENCER.createCustomSequencerPlugin(PLAYER_SEQUENCER.sequencerPluginChain.createSequencerPlugin());



