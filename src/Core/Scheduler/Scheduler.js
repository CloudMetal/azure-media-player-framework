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

// This is the public API for the Scheduler component
// All the position variables are floating point seconds

//
// The namespace object
//
var PLAYER_SEQUENCER = PLAYER_SEQUENCER || {};

// custom Scheduler Error derivation:
PLAYER_SEQUENCER.SchedulerError = function (message) {
"use strict";
    if (this === PLAYER_SEQUENCER) {
        throw new PLAYER_SEQUENCER.SchedulerError("SchedulerError constructor called without new operator!");
    }
    this.name = "PLAYER_SEQUENCER:SchedulerError";
    this.message = message || "[no message]";
    // For V8 capture the stack trace:
    if (Error.captureStackTrace) {
        Error.captureStackTrace(this, PLAYER_SEQUENCER.SchedulerError);    
    }
};
PLAYER_SEQUENCER.SchedulerError.prototype = new Error();
PLAYER_SEQUENCER.SchedulerError.prototype.constructor = PLAYER_SEQUENCER.SchedulerError;

PLAYER_SEQUENCER.createSequentialPlaylist = function () {
"use strict";

    // ---------------------------------
    // private variables
    // ---------------------------------
    var playlist = [],
        nextId = 1, // start with 1 so nextId is never false
        privateMethodKey = Math.random(),
        playlistDuration = 0,

    // ---------------------------------
    // private methods
    // ---------------------------------
    throwSetterInhibited = function ( value ) {
        throw new PLAYER_SEQUENCER.SchedulerError('setter not allowed. value: ' + value.toString());
    },

    validatePrivateMethodAccess = function ( passKey ) { 
        if (passKey !== privateMethodKey) {
            throw new PLAYER_SEQUENCER.SchedulerError('incorrect private method passKey: ' + passKey.toString());
        }
    },

    indexFromId = function ( idToFind, callerName ) {
        var i;
        for (i = 0; i < playlist.length; i += 1) {
            if (playlist[i].id === idToFind) {
                return i;
            }
        }
        throw new PLAYER_SEQUENCER.SchedulerError( (callerName || "[unnamed]") + ' called indexFromId with invalid id ' + idToFind.toString());
    },

    isNearZero = function (value, tolerance) {
        // default to 1 millisecond to accommodate number roundoff errors
        return Math.abs( value ) < (tolerance || 0.001);
    },

    findEntryIndexAtTime = function (timeToFind) {
        var i,
            startTime;

        // Search the list to find the entry containing the time point with the closest start time.
        // Note: the list is searched forward so the first of multiple entries with the same start time is found.
        for (i = 0; i < playlist.length; i += 1) {
            startTime = playlist[i].linearStartTime;
            // Note: Object is found if start time is close to timeToFind
            if (isNearZero(startTime - timeToFind) ||
                (startTime <= timeToFind && timeToFind < (startTime + playlist[i].linearDuration)) ) {
                break;
            }
        }
        return i;
    },

    // ---------------------------------
    // public sequentialPlaylist methods
    // ---------------------------------
    newSeqPlaylist = {

        // methods that change the sequentialPlaylist state:
        change: {
            createEntry: function (idSplitFrom, splitOffsetTime) {
                ///<summary>Create a new null sequentialPlaylistEntry.</summary>
                ///<param name="idSplitFrom" type="number">optional id of playlistEntry to split to generate new entry from the tail of the split.</param>
                ///<param name="splitOffsetTime" type="number">when idSplitFrom given, required time offset of the split point.</param>
                ///<returns type="Object">A playlistEntry object to be filled in before insertEntry is called using it.</returns>
                var playlistEntry,
                    myId = nextId,
                    myIdSplitFrom = nextId,
                    mySplitCount = 0,
                    indexToSplitFrom,
                    splitTimeDelta;
                nextId += 1;
                
                if (idSplitFrom) {
                    indexToSplitFrom = indexFromId(idSplitFrom, "createEntry");
                    if (playlist[indexToSplitFrom].linearDuration === 0) {
                        throw new PLAYER_SEQUENCER.SchedulerError( 'createEntry idToSplitFrom ' + idSplitFrom.toString() + ' cannot be split');
                    }
                    myIdSplitFrom = playlist[indexToSplitFrom].idSplitFrom;
                }
                // DEFINITION of playlistEntry
                playlistEntry = {
                //  -----------------------------------------------------------------------
                    clipURI: null,              // string
                    eClipType: null,            // string - 'Media', 'Static', 'VAST', 'SeekToStart', 'ProgramContent'
                    linearStartTime: 0,         // number
                    linearDuration: 0,          // number - zero for pause timeline true
                    minRenderingTime: 0,        // number - clip begin
                    maxRenderingTime: 0,        // number - clip end
                    isAdvertisement: true,      // boolean
                    playbackPolicyObj: {},      // opaque - playback policy object
                    deleteAfterPlay: false,     // boolean
                    get id () { return myId; },
                    set id (value) { throwSetterInhibited(value); },
                    get idSplitFrom () { return myIdSplitFrom; },
                    set idSplitFrom (value) { throwSetterInhibited(value); },
                    get splitCount () { return mySplitCount; },
                    set splitCount (value) { throwSetterInhibited(value); },
                    incrementSplitCount: function ( passKey ) { 
                        validatePrivateMethodAccess(passKey);
                        mySplitCount += 1; 
                    }
                //  -----------------------------------------------------------------------
                };

                if (idSplitFrom) {
                    // copy the properties (with times adjusted for the split offset)
                    splitTimeDelta = Number(splitOffsetTime);

                    playlistEntry.clipURI = playlist[indexToSplitFrom].clipURI;
                    playlistEntry.eClipType = playlist[indexToSplitFrom].eClipType;
                    playlistEntry.linearStartTime = playlist[indexToSplitFrom].linearStartTime + splitTimeDelta;
                    playlistEntry.linearDuration = playlist[indexToSplitFrom].linearDuration - splitTimeDelta;
                    playlistEntry.minRenderingTime = playlist[indexToSplitFrom].minRenderingTime + splitTimeDelta;
                    playlistEntry.maxRenderingTime = playlist[indexToSplitFrom].maxRenderingTime;
                    playlistEntry.isAdvertisement = playlist[indexToSplitFrom].isAdvertisement;
                    playlistEntry.playbackPolicyObj = playlist[indexToSplitFrom].playbackPolicyObj;
                    playlistEntry.deleteAfterPlay = playlist[indexToSplitFrom].deleteAfterPlay;
                }
                return playlistEntry;
            },
            
            insertEntry: function (playlistEntry) {
                ///<summary>Insert the provided entry at a list position based on the values.</summary>
                ///<param name="playlistEntry" type="Object">The playlistEntry to be inserted in the sequentialPlayList.</param>
                var entryFound, entrySplit, splitOffsetTime, indexFound;

                if (!playlistEntry.isAdvertisement) {
                    throw new PLAYER_SEQUENCER.SchedulerError('insertEntry of non-advertisement');
                }

                // TODO: remove this when overlay ads are implemented:
                if (playlistEntry.linearDuration !== 0) {
                    throw new PLAYER_SEQUENCER.SchedulerError('insertEntry of overlay ad is currently not supported');
                }

                indexFound = findEntryIndexAtTime(playlistEntry.linearStartTime);
                if (indexFound === playlist.length) {
                    throw new PLAYER_SEQUENCER.SchedulerError('insertEntry linearStartTime ' + playlistEntry.linearStartTime.toString() + ' outside playlist range');
                }
                entryFound = playlist[indexFound];

                splitOffsetTime = playlistEntry.linearStartTime - entryFound.linearStartTime;
                // if new entry start time close to an existing entry start
                if (isNearZero( splitOffsetTime )) {
                    // insert before entry found
                    // prevent retrograde start times in the list
                    if (playlistEntry.linearStartTime > entryFound.linearStartTime) {
                        playlistEntry.linearStartTime = entryFound.linearStartTime;
                    }
                    playlist.splice(indexFound, 0, playlistEntry);
                }
                else {
                    // split the existing entry
                    if (entryFound.isAdvertisement) {
                        throw new PLAYER_SEQUENCER.SchedulerError('insertEntry splitting ad');
                    }
                    entrySplit = this.createEntry(entryFound.id, splitOffsetTime);

                    entryFound.incrementSplitCount( privateMethodKey );
                    entryFound.maxRenderingTime = entrySplit.minRenderingTime;
                    entryFound.linearDuration = splitOffsetTime;

                    playlistEntry.linearStartTime = entryFound.linearStartTime + entryFound.linearDuration;

                    /* TODO: to support overlay ads, add the following:
                    if ( playlistEntry.linearDuration > 0) {
                        // Note: overlay ads are not allowed to span RCE clips or content split by other ads
                        if ( playlistEntry.linearDuration > entrySplit.linearDuration) {
                            throw new PLAYER_SEQUENCER.SchedulerError('insertEntry overlay beyond end of program content clip');
                        }                        
                        entrySplit.linearStartTime += playlistEntry.linearDuration;
                        entrySplit.linearDuration -= playlistEntry.linearDuration;
                    }
                    */

                    // insert new entry after the first part and the second part after that
                    playlist.splice(indexFound + 1, 0, playlistEntry);
                    indexFound = indexFromId( playlistEntry.id, "insertEntry split" );
                    playlist.splice(indexFound + 1, 0, entrySplit);
                }
            },

            insertEntryAfterEnd: function (playlistEntry) {
                ///<summary>Insert the provided entry at the end of the playList.</summary>
                ///<param name="playlistEntry" type="Object">The playlistEntry to be inserted after the end of the sequentialPlayList.</param>
                var i = playlist.length;

                if (playlistEntry.isAdvertisement && playlistEntry.linearDuration > 0) {
                    throw new PLAYER_SEQUENCER.SchedulerError('insertEntryAfterEnd an overlay ad');
                }
                if (i > 0) {
                    playlistEntry.linearStartTime = playlist[i-1].linearStartTime + playlist[i-1].linearDuration;
                }
                playlistDuration += playlistEntry.linearDuration;
                playlist.push(playlistEntry);
            },

            insertEntryBeforeBeginning: function (playlistEntry) {
                ///<summary>Insert the provided entry at the beginning of the playList.</summary>
                ///<param name="playlistEntry" type="Object">The playlistEntry to be inserted at the beginning of the sequentialPlayList.</param>
                if (playlistEntry.linearDuration > 0) {
                    // TODO: handle overlay preroll ad case (adjust underlying main content linear and rendering times)
                    throw new PLAYER_SEQUENCER.SchedulerError('insertEntryBeforeBeginning overlay ad not yet supported');
                }
                playlist.unshift(playlistEntry);
            },

            insertEntryAfterId: function (idToFind, playlistEntry) {
                ///<summary>Insert the provided entry after an existing entry.</summary>
                ///<param name="idToFind" type="number">id of playlistEntry after which the insertion is to take place.</param>
                ///<param name="playlistEntry" type="Object">The playlistEntry to be inserted after the specified entry.</param>
                var i = indexFromId( idToFind, "insertEntryAfterId" );

                if (playlist[i].eClipType === "SeekToStart") {
                    throw new PLAYER_SEQUENCER.SchedulerError('insertEntryAfterId ' + idToFind.toString() + ' cannot be inserted after SeekToStart');
                }

                if (playlistEntry.linearDuration === 0) {
                    playlistEntry.linearStartTime = playlist[i].linearStartTime + playlist[i].linearDuration;
                    playlist.splice(i + 1, 0, playlistEntry);
                }
                else {
                    // TODO: handle overlay ad case (adjust underlying main content linear and rendering times)
                    throw new PLAYER_SEQUENCER.SchedulerError('insertEntryAfterId overlay ad not yet supported');
                }
            },

            insertSeekToStart: function (playlistEntry) {
                ///<summary>Insert the provided entry before the first list item with non-zero linear duration.</summary>
                ///<param name="playlistEntry" type="Object">The SeekToStart playlist entry to be inserted.</param>
                ///<returns type="Object">The playlistEntry inserted or null if a SeekToStart entry is already in the sequentialPlaylist.</returns>
                var i;

                for (i = 0; i < playlist.length; i += 1) {
                    if (playlist[i].eClipType === "SeekToStart") {
                        return null;
                    }
                    if (playlist[i].linearDuration > 0) {
                        playlistEntry.eClipType = "SeekToStart";
                        playlist.splice(i, 0, playlistEntry);
                        return playlistEntry;
                    }
                }
                throw new PLAYER_SEQUENCER.SchedulerError('insertSeekToStart cannot be inserted inside playlist with no content');
            },        
            
            remove: function (idToRemove) {
                ///<summary>Insert the provided entry at a list position based on the values.</summary>
                ///<param name="idToRemove" type="Object">The id of the playlistEntry to be removed from the sequentialPlayList.</param>
                ///<returns type="Object">The playlistEntry that was removed.</returns>
                var objRemoved = null,
                    i = indexFromId( idToRemove, "remove" );
                    
                objRemoved = playlist[i];
                if (!objRemoved.isAdvertisement) {
                    throw new PLAYER_SEQUENCER.SchedulerError( 'remove main content currently not allowed' );
                }
                // remove the specified entry from the list:
                playlist.splice(i,1);
                if (i === playlist.length) {
                    playlistDuration -= objRemoved.linearDuration;
                }
                // Note: the "splitCount" is being used as a "changed count" here:
                objRemoved.incrementSplitCount( privateMethodKey );
                // Clear the deleteAfterPlay flag so access.onPlayedEntry will not remove again
                objRemoved.deleteAfterPlay = false;

                // if entry after the one removed was spliced from the entry before the one removed,
                if (i > 0 && i < playlist.length && playlist[i-1].idSplitFrom === playlist[i].idSplitFrom) {
                    // weld the after entry onto the before entry and indicate it has changed:
                    playlist[i-1].linearDuration += playlist[i].linearDuration + objRemoved.linearDuration;
                    playlist[i-1].maxRenderingTime = playlist[i].maxRenderingTime;
                    playlist[i-1].incrementSplitCount( privateMethodKey );
                    // indicate the after entry has changed:
                    playlist[i].incrementSplitCount( privateMethodKey );
                    // remove the after entry from the list:
                    playlist.splice(i,1);
                }
                // TODO: handle overlay ads by adjusting start times of any following ads and the
                //       next overlaid main content item and the main content item duration.
                return objRemoved;
            },

            removeAllEntries: function () {
                ///<summary>Remove all entries from the playList.</summary>
                playlist = [];
                playlistDuration = 0;
            }
        }, // end of change methods

        // Methods that only access the playlist:
        access: {
            getEntryAtTime: function (timeToFind) {
                /// <summary>Get the playlistEntry containing the given linear time point.</summary>
                /// <param name="getEntryAtTime" type="number">The time point to find.</param>
                /// <returns type="Object">The playlistEntry found (the first if multiple zero-duration entrys start at the same time)</returns>
                return playlist[findEntryIndexAtTime(timeToFind)];
            },
            
            // Fetch the entry that follows the one with the idToFind
            // returns: playlistEntry; falsy if idToFind at end of list
            // throws: SchedulerError if no list item with idToFind
            getEntryAfterId: function (idToFind) {
                /// <summary>Get the playlistEntry that follows the one with the given id.</summary>
                /// <param name="idToFind" type="number">The id of the playlistEntry to find.</param>
                /// <returns type="Object">The playlistEntry found; falsy if idToFind is at the end of the sequentialPlaylist</returns>
                var objFound = null,
                    i = indexFromId( idToFind, "fetchNext" );
                    
                if (i < (playlist.length - 1)) {
                    objFound = playlist[i + 1];
                }
                return objFound;
            },
            
            getEntryBeforeId: function (idToFind) {
                /// <summary>Get the playlistEntry that preceeds the one with the given id.</summary>
                /// <param name="idToFind" type="number">The id of the playlistEntry to find.</param>
                /// <returns type="Object">The playlistEntry found; falsy if idToFind is at the end of the sequentialPlaylist</returns>
                var objFound = null,
                    i = indexFromId( idToFind, "fetchPrev" );
                    
                if (i > 0) {
                    objFound = playlist[i - 1];
                }
                return objFound;
            },
            
            getPlaylistLinearDuration: function () {
                /// <summary>Get the total linear duration of the entire sequentialPlaylist.</summary>
                /// <returns type="number">The duration in seconds.</returns>
                return playlistDuration;
            },

            onPlayedEntry: function (playlistEntry) {
                ///<summary>Notify that a given playlistEntry has been played.</summary>
                ///<param name="playlistEntry" type="Object">The playlist entry that has been played. This entry will be removed from the sequentialPlaylist if the deleteAfterPlay flag is set.</param>
                if (playlistEntry.deleteAfterPlay) {
                    newSeqPlaylist.change.remove(playlistEntry.id);
                }
            }
        }, // end of access methods

        // Test methods
        testProbe_toJSON: function () {
            ///<summary>Return a JSON string of the entire sequentialPlaylist.</summary>
            return JSON.stringify(playlist);
        }
    };
    return newSeqPlaylist;
};
        

// The Scheduler for VOD content
PLAYER_SEQUENCER.createScheduler = function (sequentialPlaylist) {
"use strict";
    // ---------------------------------
    // private variables
    // ---------------------------------
    var mySequentialPlaylist = sequentialPlaylist.change,

    // ---------------------------------
    // private methods
    // ---------------------------------
        isDurationTooSmall = function (duration) {
        return duration < 1.0; // this value is replicated in the createContentClipParams comment below
    },

    // ---------------------------------
    // public methods
    // ---------------------------------

    myScheduler = {
        createContentClipParams: function () {
            ///<summary>Create a null parameters object for scheduling a content clip.</summary>
            ///<returns type="Object">The parameters object to be filled in before calling appendContentClip.</returns>
            return {
                clipURI: null,              // string: the Media URI
                minManifestPosition: 0,     // number: the minimum manifest time for the clip
                maxManifestPosition: 0      // number: the maximum manifest time for the clip
                                            // Note: duration is (max - min) and must be > 1.0
            };
        },

        createScheduleClipParams: function () {
            ///<summary>Create a null parameters object for scheduling an advertisement clip.</summary>
            ///<returns type="Object">The parameters object to be filled in before calling scheduleClip.</returns>
            return {
                clipURI: null,              // string: the clip URL
                eClipType: null,            // string: the the clip type: 'Media', 'Static', or 'VAST'
                minManifestPosition: 0,     // number: the minimum manifest time for the clip
                maxManifestPosition: 0,     // number: the maximum manifest time the clip will play to (duration of the clip)
                startTime: 0,               // number: the clip start time in the linear time; only used for eTypeMidroll
                linearDuration: 0,          // number: 0 for pauseTimeline true ad, and duration for pauseTimeline false ad
                playbackPolicyObj: {},      // Object: the opaque playback policy object for the clip (sequencer implementation dependent)
                deleteAfterPlay: false,     // boolean: if the ad should be deleted after playback
                eRollType: null,            // string: the "roll" type: 'Pre', 'Post', 'Mid', 'Now', or 'Pod'
                appendTo: -1                // number: the id of the playlistEntry to append to in an ad pod, otherwise leave default of -1
            };
        },

        reset: function () {
            ///<summary>Reset the schedule to be completely empty.</summary>
            mySequentialPlaylist.removeAllEntries();
        },

        removeClip: function (params) {
            ///<summary>Remove a clip.</summary>
            ///<param name="params" type="Object">An object with property: playlistEntryId (id entry to be removed).</param>
            ///<returns type="Object">The playlistEntry that was removed.</returns>
            return mySequentialPlaylist.remove(params.playlistEntryId);
        },

        appendContentClip: function (params) {
            ///<summary>Append a content (non-ad media) clip to the sequential playlist to build up the main content. Must be called one or more times before scheduleClip.</summary>
            ///<param name="params" type="Object">An object obtained with createContentClipParams and then filled in with specific values.</param>
            ///<returns type="Object">The playlistEntry created for the clip.</returns>
            var playlistEntry;

            playlistEntry = mySequentialPlaylist.createEntry();

            playlistEntry.clipURI = params.clipURI;
            // Note: eClipType is ignored:
            playlistEntry.eClipType = 'ProgramContent';

            if (typeof params.minManifestPosition !== 'number') {
                throw new PLAYER_SEQUENCER.SchedulerError('appendContentClip minManifestPosition not a number');
            }
            playlistEntry.minRenderingTime = params.minManifestPosition;

            if (typeof params.maxManifestPosition !== 'number') {
                throw new PLAYER_SEQUENCER.SchedulerError('appendContentClip maxManifestPosition not a number');
            }
            playlistEntry.maxRenderingTime = params.maxManifestPosition;

            playlistEntry.linearDuration = playlistEntry.maxRenderingTime - playlistEntry.minRenderingTime;

            if (isDurationTooSmall(playlistEntry.linearDuration)) {
                throw new PLAYER_SEQUENCER.SchedulerError('appendContentClip duration too small: ' + playlistEntry.linearDuration.toString());
            }
            playlistEntry.isAdvertisement = false;

            mySequentialPlaylist.insertEntryAfterEnd(playlistEntry);

            return playlistEntry;
        },

        scheduleClip: function (params) {
            ///<summary>Schedule an ad clip. Must not be called until main content that contains the clip has been scheduled.</summary>
            ///<param name="params" type="Object">An object obtained with createScheduleClipParams and then filled in with specific values.</param>
            ///<returns type="Object">The playlistEntry created for the clip.</returns>
            var playlistEntry, renderingDuration;

            playlistEntry = mySequentialPlaylist.createEntry();

            playlistEntry.clipURI = params.clipURI;
            playlistEntry.eClipType = params.eClipType;
            playlistEntry.linearDuration = params.linearDuration;

            if (params.minManifestPosition !== undefined) {
                playlistEntry.minRenderingTime = params.minManifestPosition;
            }
            if (params.maxManifestPosition !== undefined) {
                renderingDuration = params.maxManifestPosition - playlistEntry.minRenderingTime;
                if (isDurationTooSmall(renderingDuration)) {
                    throw new PLAYER_SEQUENCER.SchedulerError('scheduleClip maxManifestPosition too small. Delta: ' + renderingDuration.toString());
                }
                playlistEntry.maxRenderingTime = params.maxManifestPosition;
            }
            else if (playlistEntry.linearDuration === 0) {
                throw new PLAYER_SEQUENCER.SchedulerError('scheduleClip cannot determine maxRenderingTime given missing maxManifestPosition and zero linearDuration');
            }
            else {
                playlistEntry.maxRenderingTime = playlistEntry.minRenderingTime + playlistEntry.linearDuration;
            }

            playlistEntry.isAdvertisement = true;
            // NOTE: For now do not allow overlay ads
            // TODO: preroll ads should always be pause-timeline-true (zero linear duration)
            if (playlistEntry.linearDuration > 0) {
                throw new PLAYER_SEQUENCER.SchedulerError('scheduleClip overlay currently not supported');
            }

            if (params.playbackPolicyObj !== undefined) {
                playlistEntry.playbackPolicyObj = params.playbackPolicyObj;
            }
            if (params.deleteAfterPlay !== undefined) {
                playlistEntry.deleteAfterPlay = params.deleteAfterPlay;
            }

            switch (params.eRollType) {
                case 'Pre':
                    mySequentialPlaylist.insertEntryBeforeBeginning(playlistEntry);
                    break;

                case 'Post':
                    mySequentialPlaylist.insertEntryAfterEnd(playlistEntry);
                    break;

                case 'Pod':
                    mySequentialPlaylist.insertEntryAfterId(params.appendTo, playlistEntry);
                    break;

                case 'Mid':
                    playlistEntry.linearStartTime = params.startTime;
                    mySequentialPlaylist.insertEntry(playlistEntry);
                    break;

                default:
                    throw new PLAYER_SEQUENCER.SchedulerError('scheduleClip invalid eRollType: ' + params.eRollType.toString());
            }

            return playlistEntry;
        },

        setSeekToStart: function (params) {
            ///<summary>Set seek-to-start marker. Must not be called until main content has been scheduled.</summary>
            ///<param name="params" type="Object">An optional object with a clipURI property (indicates live content).</param>
            ///<returns type="Object">The playlistEntry created for the clip.</returns>
            var playlistEntry;

            playlistEntry = mySequentialPlaylist.createEntry();

            if (params && params.clipURI) {
                playlistEntry.clipURI = params.clipURI;
            }
            playlistEntry.eClipType = 'SeekToStart';
            playlistEntry.maxRenderingTime = -1; // flag unbounded
            playlistEntry.deleteAfterPlay = true;
            playlistEntry.isAdvertisement = true;

            return mySequentialPlaylist.insertSeekToStart(playlistEntry);
        },
        
        runJSON: function (paramsJSON) {
            ///<summary>Invoke a scheduler method using a JSON string and returning the result as a JSON string.</summary>
            ///<param name="paramsJSON" type="String">The method name and params expressed in a JSON string. There must be a top level property "func" string with the name of the method to invoke. Method params can either be all top level or within a containing "params" object.</param>
            ///<returns type="String">The method results expressed is a JSON string. If an exception was thrown, a top level object "EXCEPTION" will contain standard Error fields.</returns>

            var params, result, stackArray, stackAsJSON, i;

            try {
                params = JSON.parse(paramsJSON);

                if (!params || (typeof params.func !== 'string')) {
                    throw new PLAYER_SEQUENCER.SchedulerError('runJSON func property missing or not a string');
                }

                if (params.params) {
                    result = myScheduler[params.func](params.params);
                }
                else {
                    result = myScheduler[params.func](params);
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
    return myScheduler;
};

// ------------------------------------------------------------------------------------------------
// Singletons for the sequential playlist and the scheduler
// Note: These are declared here for simplicity in the initial single-instance implementation.
//       For multiple instance implementations, these would be moved to an instance manager.
// ------------------------------------------------------------------------------------------------

PLAYER_SEQUENCER.sequentialPlaylist = PLAYER_SEQUENCER.createSequentialPlaylist();

PLAYER_SEQUENCER.scheduler = PLAYER_SEQUENCER.createScheduler(PLAYER_SEQUENCER.sequentialPlaylist);
