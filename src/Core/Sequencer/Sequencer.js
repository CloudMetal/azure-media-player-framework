// ----------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// ----------------------------------------------------------------------------
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

// This file contains the public methods for Sequencer Chain head access and the Sequencer plugin factory.
// It also contains the hidden default (last) Sequencer implementation.
// All the position variables are floating point seconds.

//
// The namespace object
//
var PLAYER_SEQUENCER = PLAYER_SEQUENCER || {};

// custom Sequencer Error derivation:
PLAYER_SEQUENCER.SequencerError = function (message) {
    ///<summary>Constructor for the custom Sequencer Error derivation.</summary>
    ///<param name="message" type="String">A human readable error message within the Sequencer Error context.</param>
    ///<returns type="Object">A new Sequencer Error object instance.</returns>
    "use strict";
    if (this === PLAYER_SEQUENCER) {
        throw new PLAYER_SEQUENCER.SequencerError("SequencerError constructor called without new operator!");
    }
    this.name = "PLAYER_SEQUENCER:SequencerError";
    this.message = message || "[no message]";
    // For V8 capture the stack trace:
    if (Error.captureStackTrace) {
        Error.captureStackTrace(this, PLAYER_SEQUENCER.SequencerError);    
    }
};
PLAYER_SEQUENCER.SequencerError.prototype = new Error();
PLAYER_SEQUENCER.SequencerError.prototype.constructor = PLAYER_SEQUENCER.SequencerError;

// -------------------------
// The playback segment pool
// -------------------------
// Note: The purpose of this pool is to provide a unique mapping of segment id numbers to 
//       playback segment objects which allows referencing the objects through the JSON thunk.
//       Therefore, the pool can be a Singleton regardless of the number of Sequencer instances used.
//
PLAYER_SEQUENCER.playbackSegmentPool = (function () {
"use strict";

    var nextSegmentId = 1,          // start with 1 so never false
        poolBaseId = nextSegmentId, // the segmentId of the zeroth pool element
        pool = [],
    
    // private methods
    throwSetterInhibited = function ( value ) {
        throw new PLAYER_SEQUENCER.SequencerError('setter not allowed. value: ' + value.toString());
    };

    return {
        createPlaybackSegment: function (aClip, aStartTime, aPlaybackRate) {
            ///<summary>Create a new playbackSegment object</summary>
            ///<param name="aClip" type="Object">A reference to a Scheduler sequentialPlaylist object</param>
            ///<param name="aStartTime" type="Number">manifest time of where to start playing in the new segment</param>
            ///<param name="aPlaybackRate" type="Number">initial playback rate</param>
            ///<returns type="Object">playbackSegment object that was created</returns>
            var myId = nextSegmentId,
                myClip = aClip,
                myStartTime = aStartTime,
                myPlaybackRate = aPlaybackRate,
                mySplitCount = aClip.splitCount,
                playbackSegment;

            nextSegmentId += 1;

            // DEFINITION of a playbackSegment:
            playbackSegment = {
                /// <field name="clip" type="Object" mayBeNull="true">reference to a Scheduler sequentialPlaylist object</field>
                get clip() { return myClip; },
                set clip(value) { myClip = value; mySplitCount = value.splitCount; },
                /// <field name="initialPlaybackStartTime" type="Number">manifest time of where to start playing in the new segment</field>
                get initialPlaybackStartTime() { return myStartTime; },
                set initialPlaybackStartTime(value) { throwSetterInhibited(value); },
                /// <field name="initialPlaybackRate" type="Number">initial playback rate</field>
                get initialPlaybackRate() { return myPlaybackRate; },
                set initialPlaybackRate(value) { throwSetterInhibited(value); },
                /// <field name="segmentId" type="Number">unique id number of the playback segment</field>
                get segmentId() { return myId; },
                set segmentId(value) { throwSetterInhibited(value); },
                /// <field name="isClipChanged" type="Boolean">true if clip has changed</field>
                get isClipChanged() { return mySplitCount !== myClip.splitCount; },
                set isClipChanged(value) { throwSetterInhibited(value); }
            };
            pool[myId - poolBaseId] = playbackSegment;
            return playbackSegment;
        },
        releasePlaybackSegment: function (segmentId) {
            ///<summary>Release the segment pool reference to the playback segment object so it can be GCed</summary>
            ///<param name="segmentId" type="Number">The segmentId number of the playback segment to be released from the pool</param>
            if (pool[segmentId - poolBaseId] === undefined) {
                throw new PLAYER_SEQUENCER.SequencerError('invalid releasePlaybackSegment Id: ' + segmentId.toString());
            }
            if (segmentId === poolBaseId) {
                do {
                    // shift out all contiguous released items starting at the base Id
                    pool.shift();
                    poolBaseId += 1;
                } while (pool.length > 0 && pool[0] === null); 
            }
            else {
                // just release the Id and it will be shifted out when all before are released
                pool[segmentId - poolBaseId] = null;
            }
        },
        getPlaybackSegment: function (segmentId) {
            ///<summary>Get a a reference to the playbackSegment object with the given segmentId</summary>
            ///<param name="segmentId" type="Number">The segmentId number of the playback segment to be referenced</param>
            ///<returns type="Object">playbackSegment object reference</returns>
            var ps = pool[segmentId - poolBaseId], 
                ex;
            if (!ps) {
                ex = new PLAYER_SEQUENCER.SequencerError('invalid getPlaybackSegment Id: ' + segmentId.toString());
                throw ex;
            }
            return ps;
        },
        testProbe_toJSON: function () {
            ///<summary>For testing purposes, return JSON string of the entire playbackSegment pool</summary>
            ///<returns type="String">JSON of the entire playbackSegment pool</returns>
            return '{' + JSON.stringify(pool) + ',"poolBaseId":' + poolBaseId.toString() + ',"nextSegmentId":' + nextSegmentId.toString() + '}';
        },
        testProbe_reset: function () {
            ///<summary>For testing purposes, reset the entire playbackSegment pool</summary>
            pool = [];
            poolBaseId = nextSegmentId; // the segmentId of the zeroth pool element
        }
    };
}());

//
// -------------------------
// Sequencer plugin chain
// -------------------------
//
PLAYER_SEQUENCER.createSequencerPluginChain = function ( sequentialPlaylistAccessContext ) {
    ///<summary>Create a sequencer plugin chain object with all the methods for accessing the chain instance.</summary>
    ///<param name="sequentialPlaylistAccessContext" type="Object">The object with methods for accessing the Scheduler sequentialPlaylist instance to be used by this plugin chain.</param>
    ///<returns type="Object">A new sequencer plugin factory object with methods for creating new pass-through plugins and using the chain.</returns>
    "use strict";

    var sequentialPlaylistAccess = sequentialPlaylistAccessContext,
        firstSequencer = null;
    
    return {
        //
        // Sequencer plugin factory object
        // This factory creates a pass-through object which defines all the methods
        //     a sequencer plugin must either override or allow to be passed through.
        // This could be thought of as the "interface definition" for a sequencer plug-in implementation.
        // Note that the prototype for the object created is simply that of Object.
        //
        
        createSequencerPlugin: function () {
            ///<summary>Create a pass-through plugin object which defines all the methods a sequencer plugin can override.</summary>
            ///<returns type="Object">A new sequencer plugin pass-through object.</returns>
            var nextSequencer = null,
        
            newSequencer = {
                getNextSequencer: function () {
                    ///<summary>Get the hidden nextSequencer value so method overrides can conditionally pass through to the next sequencer.</summary>
                    ///<returns type="Object">A reference to the next sequencer in the plugin chain.</returns>
                    return nextSequencer;
                },

                getSequentialPlaylistAccess: function () {
                    ///<summary>Get the hidden sequentialPlaylistAccess value so method overrides can access the correct sequentialPlaylist.</summary>
                    ///<returns type="Object">A reference to the sequentialPlaylist.access object for this plugin chain.</returns>
                    return sequentialPlaylistAccess;
                },

                manifestToSeekbarTime: function ( params ) {
                    ///<summary>Convert manifest time to seekbar time. Should be called several times per second to keep seekbar updated and catch playlist changes.</summary>
                    ///<param name="params" type="Object">An object with properties: currentSegmentId, playbackRate, currentPlaybackPosition</param>
                    ///<returns type="Object">An object with properties: currentSeekbarPosition, minSeekbarPosition, maxSeekbarPosition, playbackPolicy, playbackRangeExceeded</returns>
                    return nextSequencer.manifestToSeekbarTime(params);
                },
        
                manifestToLinearTime: function ( params ) {
                    ///<summary>Convert manifest time to linear time. Used to determine where to resume from last played position.</summary>
                    ///<param name="params" type="Object">An object with properties: currentSegmentId, currentPlaybackPosition (in manifest time)</param>
                    ///<returns type="Object">An object with properties: linearPosition, isOnLinearTimeline</returns>
                    return nextSequencer.manifestToLinearTime( params );
                },
        
                seekFromLinearPosition: function ( params ) {
                    ///<summary>Seek to linear time. Used to resume from last played position (no currentSegmentId given0 or to seek out of a zero-linear-duration currentSegmentId.</summary>
                    ///<param name="params" type="Object">An object with properties: currentSegmentId (optional), linearSeekPosition</param>
                    ///<returns type="Object">A playback segment object reference</returns>
                    return nextSequencer.seekFromLinearPosition( params );
                },
        
                seekFromSeekbarPosition: function ( params ) {
                    ///<summary>Seek to a position relative to the current playback segment seekbar range.</summary>
                    ///<param name="params" type="Object">An object with properties: currentSegmentId, seekbarSeekPosition</param>
                    ///<returns type="Object">A playback segment object reference (may be same as that for currentSegmentId)</returns>
                    return nextSequencer.seekFromSeekbarPosition( params );
                },
        
                onEndOfMedia: function ( params ) {
                    ///<summary>Notify end of playing the current playback segment to get a new playback segment object for the next segment in the sequence. The Scheduler is notified the playlist entry for the current playback segment has been played.</summary>
                    ///<param name="params" type="Object">An object with properties: currentSegmentId, currentPlaybackPosition (in manifest time), currentPlaybackRate, isNotPlayed, isEndOfSequence</param>
                    ///<returns type="Object" mayBeNull="true">The new playback segment object reference (null when at end of list)</returns>
                    return nextSequencer.onEndOfMedia( params );
                },
        
                onEndOfBuffering: function ( params ) {
                    ///<summary>Notify end of buffering the playback segment to get a new playback segment object for the next segment in the sequence to buffer. The Scheduler is NOT notified the playlist entry for the current playback segment has been played.</summary>
                    ///<param name="params" type="Object">An object with properties: currentSegmentId, currentPlaybackPosition (in manifest time), currentPlaybackRate</param>
                    ///<returns type="Object" mayBeNull="true">The new playback segment object reference (null when at end of list)</returns>
                    return nextSequencer.onEndOfBuffering( params );
                },
        
                onError: function ( params ) {
                    ///<summary>Notify playback error to get a new playback segment object for the next segment in the sequence to use after an error.</summary>
                    ///<param name="params" type="Object">An object with properties: currentSegmentId, currentPlaybackPosition (in manifest time), currentPlaybackRate, isNotPlayed, isEndOfSequence, errorDescription</param>
                    ///<returns type="Object" mayBeNull="true">The new playback segment object reference (null when sequence is terminated)</returns>
                    return nextSequencer.onError( params );
                },

                testProbe: function ( params ) {
                    ///<summary>For testing purposes: generic invocation of a test probe. This is a "tunneling" mechanism for a private contract between the caller and a specific sequencer plugin.</summary>
                    ///<param name="params" type="Object">An object with properties dependent upon the specific probe to be performed.</param>
                    ///<returns mayBeNull="true">An object of type and value dependent upon the specific probe that was performed.</returns>
                    return nextSequencer.testProbe( params );
                }
            }; // end of newSequencer
            
            nextSequencer = firstSequencer;
            firstSequencer = newSequencer;

            return newSequencer;
        },
        
        getFirstSequencer: function () {
            ///<summary>Get a reference to the first sequencer in the plugin chain. This should always be used for all sequencer plugin method invocations.</summary>
            ///<returns type="Object">A reference to the first sequencer in the plugin chain.</returns>
            return firstSequencer;
        },

        runJSON: function ( paramsJSON ) {
            ///<summary>Invoke a sequencer plugin method using a JSON string and returning the result as a JSON string.</summary>
            ///<param name="paramsJSON" type="String">The method name and params expressed in a JSON string. There must be a top level property "func" string with the name of the method to invoke. Method params can either be all top level or within a containing "params" object.</param>
            ///<returns type="String">The method results expressed is a JSON string. If an exception was thrown, a top level object "EXCEPTION" will contain standard Error fields.</returns>

            var params, result, stackArray, stackAsJSON, i;

            try {
                params = JSON.parse(paramsJSON);

                if (!params || (typeof params.func !== 'string')) {
                    throw new PLAYER_SEQUENCER.SequencerError('runJSON func property missing or not a string');
                }

                if (params.params) {
                    result = firstSequencer[params.func](params.params);
                }
                else {
                    result = firstSequencer[params.func](params);
                }
            }
            catch (ex) {
                // JSON.stringify() does not appear to work for exceptions, so generate explicitly:
                if (ex.stack) {
                    stackArray = ex.stack.split('\n');
                    stackAsJSON = "";
                    for (i = 0; i < stackArray.length; i += 1)
                    {
                        if (i > 0) {
                            stackAsJSON += ',';
                        }
                        stackAsJSON += '"' + stackArray[i] + '"';
                    }
                    return '{"EXCEPTION":{"name":"' + ex.name + '","message":"' + ex.message + '","stack":[' + stackAsJSON + ']}}';
                }
                return '{"EXCEPTION":{"name":"' + ex.name + '","message":"' + ex.message + '"}}';
            }
            return JSON.stringify(result);
        }
    };
};

// ------------------------------------------------------------------------------------------------
// Default (last in chain) sequencer
// ------------------------------------------------------------------------------------------------

PLAYER_SEQUENCER.createDefaultSequencerPlugin = function (basePlugin) {
"use strict";

    // private variables and methods
    var mySequentialPlaylist = basePlugin.getSequentialPlaylistAccess(),
        myPlaybackSegmentPool = PLAYER_SEQUENCER.playbackSegmentPool,

    myOnEnd = function ( params, isEndOfMedia ) {
        /* params:
        currentSegmentId            // number: the unique Id for the playback segment
        currentPlaybackPosition     // number: the current playback position in manifest time
        currentPlaybackRate         // number: the current playback rate
        isNotPlayed                 // boolean: suppress any "is played" processing
        isEndOfSequence             // boolean: do not create a new playbackSegment
        */
        var entry = myPlaybackSegmentPool.getPlaybackSegment(params.currentSegmentId).clip,
            nextEntry,
            newSegment = null,
            isPlayForward = 0 <= params.currentPlaybackRate,
            currentLinearPosition,
            initialPlaybackStartTime;
        
        if (!isEndOfMedia || !params.isEndOfSequence) {
            nextEntry = isPlayForward ? mySequentialPlaylist.getEntryAfterId(entry.id) : mySequentialPlaylist.getEntryBeforeId(entry.id);
        }
        // nextEntry is defined to be falsey when getEntryAfter/BeforeId runs off the end of the playlist
        if (nextEntry) {
            initialPlaybackStartTime = isPlayForward ? nextEntry.minRenderingTime : nextEntry.maxRenderingTime;
            newSegment = myPlaybackSegmentPool.createPlaybackSegment(nextEntry, initialPlaybackStartTime, params.currentPlaybackRate);
        }

        if (isEndOfMedia) {
            if (!params.isNotPlayed) {
                mySequentialPlaylist.onPlayedEntry(entry);
            }
            myPlaybackSegmentPool.releasePlaybackSegment(params.currentSegmentId);

            // if onPlayedEntry caused welding of nextEntry
            if (nextEntry && newSegment.isClipChanged) {
                // switch nextEntry to the playlist entry for the linear start time of the welded entry
                currentLinearPosition = nextEntry.linearStartTime;
                nextEntry = mySequentialPlaylist.getEntryAtTime(currentLinearPosition);
                if (!nextEntry) {
                    throw new PLAYER_SEQUENCER.SequencerError('myOnEnd failed to find anealed playlist entry at time ' + currentLinearPosition.toString());
                }
                // replace newSegment clip with the new playlist entry
                newSegment.clip = nextEntry;
            }
        }

        return newSegment;
    };

    // Replace the default pass-through methods
    // NOTE: Any that are missed (or mis-spelled) will cause an exception when
    //       the default pass-through uses its null 'nextSequencer' value.
    
    basePlugin.manifestToSeekbarTime = function ( params ) {
        /* params:
        currentSegmentId,           // number: the unique Id for the playback segment
        playbackRate,               // number: the current playback rate
        currentPlaybackPosition,    // number: the current position in manifest time
        */
        var currentSegment = myPlaybackSegmentPool.getPlaybackSegment(params.currentSegmentId),
            entry = currentSegment.clip,
            playbackRate = params.playbackRate,
            currentPlaybackPosition = params.currentPlaybackPosition,
            minManifestPosition = entry.minRenderingTime,
            maxManifestPosition = entry.maxRenderingTime,
            currentSeekbarPosition = currentPlaybackPosition - minManifestPosition,
            minSeekbarPosition = 0,
            maxSeekbarPosition = 0,
            playbackPolicy = null,
            playbackRangeExceeded = false,
            updatedEntry;

        if (currentSegment.clip.isAdvertisement) {
            playbackPolicy = entry.playbackPolicyObj;
            maxSeekbarPosition = maxManifestPosition - minManifestPosition;

            // currentSegment.isClipChanged cannot happen for an ad
            
            // clamp currentSeekbarPosition within min/max
            if (currentSeekbarPosition < minSeekbarPosition) {
                currentSeekbarPosition = minSeekbarPosition;
            }
            else if (maxSeekbarPosition < currentSeekbarPosition) {
                currentSeekbarPosition = maxSeekbarPosition;
            }
        }
        else {
            // for non-ad get the max seekbar position (min is always zero)
            maxSeekbarPosition = mySequentialPlaylist.getPlaylistLinearDuration();
            currentSeekbarPosition += entry.linearStartTime;

            if (currentSegment.isClipChanged) {
                updatedEntry = mySequentialPlaylist.getEntryAtTime(currentSeekbarPosition);
                if (!updatedEntry) {
                    throw new PLAYER_SEQUENCER.SequencerError(
                        'manifestToSeekbarTime failed to find anealed playlist entry at time ' + currentSeekbarPosition.toString());
                }
                if (currentSegment.clip.idSplitFrom === updatedEntry.idSplitFrom) {
                    // Replace currentSegment clip with the new welded/split playlist entry.
                    currentSegment.clip = updatedEntry;
                    // Note: the currentSeekbarPosition must be within range since the updatedEntry contains it.
                } else {
                    // currentPlaybackPosition changed to a different idSplitFrom clip
                    playbackRangeExceeded = true;
                }
            }
        }

        if (!updatedEntry && 
            ((playbackRate < 0 && currentPlaybackPosition < minManifestPosition) ||
            (playbackRate >= 0 && maxManifestPosition < currentPlaybackPosition))) {
            playbackRangeExceeded = true;
        }

        return {
            currentSeekbarPosition: currentSeekbarPosition,
            minSeekbarPosition: minSeekbarPosition,
            maxSeekbarPosition: maxSeekbarPosition,
            playbackPolicy: playbackPolicy,
            playbackRangeExceeded: playbackRangeExceeded
        };
    };

    basePlugin.manifestToLinearTime = function ( params ) {
        /* params:
        currentSegmentId,           // number: the unique Id for the playback segment
        currentPlaybackPosition     // number: the current playback position in manifest time
        */
        var currentSegment = myPlaybackSegmentPool.getPlaybackSegment(params.currentSegmentId),
            positionOffset = params.currentPlaybackPosition - currentSegment.clip.minRenderingTime,
            result = currentSegment.clip.linearStartTime;

        if (currentSegment.clip.linearDuration > 0 && positionOffset > 0) {
            // NOTE: result is *not* clipped to maxRenderingTime
            result += positionOffset;
        }
        return result;
    };

    basePlugin.seekFromLinearPosition = function ( params ) {
        /* params:
        currentSegmentId,           // number: optional unique Id for the currrent playback segment; 0 or undefined for no current segment
        linearSeekPosition          // number: the linear position to seek to, used mainly for resuming from the previous session
        */
        var seekPlaylistEntry = mySequentialPlaylist.getEntryAtTime(params.linearSeekPosition),
            currentSegment,
            initialPlaybackRate = 1,
            initialPlaybackStartTime;

        if (params.currentSegmentId) {
            currentSegment = myPlaybackSegmentPool.getPlaybackSegment(params.currentSegmentId);
        }

        if (!seekPlaylistEntry) {
            if (currentSegment) {
                myPlaybackSegmentPool.releasePlaybackSegment(currentSegment.segmentId);
            }
            throw new PLAYER_SEQUENCER.SequencerError('seekFromLinearPosition outside playlist range');
        }

        if (currentSegment) {
            myPlaybackSegmentPool.releasePlaybackSegment(currentSegment.segmentId);
            initialPlaybackRate = currentSegment.initialPlaybackRate;
        }
        initialPlaybackStartTime = seekPlaylistEntry.minRenderingTime + (params.linearSeekPosition - seekPlaylistEntry.linearStartTime);
        currentSegment = myPlaybackSegmentPool.createPlaybackSegment(seekPlaylistEntry, initialPlaybackStartTime, initialPlaybackRate);

        return currentSegment;
    };

    basePlugin.seekFromSeekbarPosition = function ( params ) {
        /* params:
        currentSegmentId,           // number: the unique Id for the playback segment
        seekbarSeekPosition         // number: the seek position in seekbar time, used for user seek
        */
        var currentSegment = myPlaybackSegmentPool.getPlaybackSegment(params.currentSegmentId),
            seekPlaylistEntry,
            seekPlaybackSegment,
            initialPlaybackRate,
            initialPlaybackStartTime;

        // Prevent seekbarSeekPosition from being non-negative
        if (params.seekbarSeekPosition < 0) {
            params.seekbarSeekPosition = 0;
        }

        if (currentSegment.clip.linearDuration > 0) {
            // Note: For non-zero-duration clips, seekbar time is the same as linear time.
            seekPlaylistEntry = mySequentialPlaylist.getEntryAtTime(params.seekbarSeekPosition);
            if (!seekPlaylistEntry) {
                throw new PLAYER_SEQUENCER.SequencerError('seekFromSeekbarPosition outside playlist range');
            }
            initialPlaybackRate = currentSegment.initialPlaybackRate;
            initialPlaybackStartTime = seekPlaylistEntry.minRenderingTime;
            // if new clip is not zero duration, offset initialPlaybackStartTime by the remaining seek distance
            if (seekPlaylistEntry.linearDuration > 0) {
                initialPlaybackStartTime += (params.seekbarSeekPosition - seekPlaylistEntry.linearStartTime);
            }
        }
        else if (params.seekbarSeekPosition > currentSegment.clip.maxRenderingTime - currentSegment.clip.minRenderingTime) {
            // for zero-duration clips seeking must be within the clip
            throw new PLAYER_SEQUENCER.SequencerError('seekFromSeekbarPosition outside segment range');
        }
        else {
            // use the same zero-duration clip to create the new segment
            seekPlaylistEntry = currentSegment.clip;
            initialPlaybackRate = currentSegment.initialPlaybackRate;
            initialPlaybackStartTime = seekPlaylistEntry.minRenderingTime + params.seekbarSeekPosition;
        }
        seekPlaybackSegment = myPlaybackSegmentPool.createPlaybackSegment(seekPlaylistEntry, initialPlaybackStartTime, initialPlaybackRate);

        // Only if there were no exceptions is the previous playbackSegment released.
        myPlaybackSegmentPool.releasePlaybackSegment(currentSegment.segmentId);

        return seekPlaybackSegment;
    };

    basePlugin.onEndOfMedia = function ( params ) {
        return myOnEnd(params, true);
    };

    basePlugin.onEndOfBuffering = function ( params ) {
        return myOnEnd(params, false);
    };

    basePlugin.onError = function ( params ) {
        // NOTE: The default implementation treats onError the same as onEndOfMedia.
        //       A sequencer plugin is required to take some other action.
        return myOnEnd(params, true);
    };

    basePlugin.testProbe = function ( params ) {
        // TODO: add testProbe functionallity based on 'params'
        return "default sequencer";
    };
};

// ------------------------------------------------------------------------------------------------
// Singleton for the sequencer plugin chain and the creation of the base sequencer plugin.
// Note: These are declared here for simplicity in the initial single-instance implementation.
//       For multiple instance implementations, these would be moved to an instance manager.
// ------------------------------------------------------------------------------------------------
//
// NOTE: The createSequencerPlugin (for the parameter to createDefaultSequencerPlugin) must be called 
//       immediately after the createSequencerPluginChain to ensure the default plugin is the last in the chain.
//
PLAYER_SEQUENCER.sequencerPluginChain = PLAYER_SEQUENCER.createSequencerPluginChain(PLAYER_SEQUENCER.sequentialPlaylist.access);

PLAYER_SEQUENCER.createDefaultSequencerPlugin(PLAYER_SEQUENCER.sequencerPluginChain.createSequencerPlugin());
