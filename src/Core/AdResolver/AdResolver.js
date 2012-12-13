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

// AdResolver module implementation.

// Inform linters of our namespaces:
/*global PLAYER_SEQUENCER_TEST_LIBRARY, DOMParser, Text, Document, Element, Attr, CDATASection */

//
// The namespace object
//
var PLAYER_SEQUENCER = PLAYER_SEQUENCER || {};

// custom AdResolver Error derivation:
PLAYER_SEQUENCER.AdResolverError = function (message) {
    ///<summary>Constructor for the custom Sequencer Error derivation.</summary>
    ///<param name="message" type="String">A human readable error message within the Sequencer Error context.</param>
    ///<returns type="Object">A new Sequencer Error object instance.</returns>
    "use strict";
    if (this === PLAYER_SEQUENCER) {
        throw new PLAYER_SEQUENCER.AdResolverError("AdResolverError constructor called without new operator!");
    }
    this.name = "PLAYER_SEQUENCER:AdResolverError";
    this.message = message || "[no message]";
    // For V8 capture the stack trace:
    if (Error.captureStackTrace) {
        Error.captureStackTrace(this, PLAYER_SEQUENCER.AdResolverError);    
    }
};
PLAYER_SEQUENCER.AdResolverError.prototype = new Error();
PLAYER_SEQUENCER.AdResolverError.prototype.constructor = PLAYER_SEQUENCER.AdResolverError;

// -------------------------
// The AdResolver Entry pool
// -------------------------
// Note: The purpose of this pool is to provide a unique mapping of id numbers to adResolverEntry
//       objects which allows holding references to objects through the JSON thunk.
//       Therefore, the pool can be a Singleton since the objects are independent.
//
PLAYER_SEQUENCER.theAdResolverEntryPool = (function () {
"use strict";

    var poolNextEntryId = 1,          // start with 1 so id is always truthy
        poolBaseId = poolNextEntryId, // the segmentId of the zeroth pool element
        pool = [],
    
    // private methods
    throwSetterInhibited = function ( value ) {
        throw new PLAYER_SEQUENCER.AdResolverError('setter not allowed. value: ' + value.toString());
    };

    return {
        createEntry: function (aParsedDocument) {
            ///<summary>Create a new AdResolverEntry object</summary>
            ///<param name="aParsedDocument" type="Object">A reference to a DOM document object</param>
            ///<returns type="Number">The idNumber of the AdResolver entry created</param>
            var myIdNumber = poolNextEntryId,
                myParsedDocument = aParsedDocument,
                adResolverEntry;

            poolNextEntryId += 1;

            // DEFINITION of a AdResolverEntry:
            adResolverEntry = {
                /// <field name="idNumber" type="Number">unique id number of the AdResolver entry</field>
                get idNumber() { return myIdNumber; },
                set idNumber(value) { throwSetterInhibited(value); },
                /// <field name="parsedDocument" type="Object">reference to a parsed XML document object</field>
                get parsedDocument() { return myParsedDocument; },
                set parsedDocument(value) { 
                    if (myParsedDocument) {
                        throwSetterInhibited(value); 
                    } else {
                        myParsedDocument = value;
                    }
                }
            };
            pool[myIdNumber - poolBaseId] = adResolverEntry;
            return adResolverEntry;
        },

        releaseEntry: function (idNumber) {
            ///<summary>Release the entry pool reference to the AdResolver entry object so it can be GCed</summary>
            ///<param name="idNumber" type="Number">The idNumber of the AdResolver entry to be released from the pool</param>
            if (pool[idNumber - poolBaseId] === undefined) {
                throw new PLAYER_SEQUENCER.AdResolverError('invalid releaseEntry Id: ' + idNumber.toString());
            }
            if (idNumber === poolBaseId) {
                do {
                    // shift out all contiguous released items starting at the base Id
                    pool.shift();
                    poolBaseId += 1;
                } while (pool.length > 0 && pool[0] === null); 
            }
            else {
                // just release the Id and it will be shifted out once all those before it have been released
                pool[idNumber - poolBaseId] = null;
            }
        },

        getEntryFromId: function (idNumber) {
            ///<summary>Get a a reference to the AdResolver entry object with the given idNumber</summary>
            ///<param name="idNumber" type="Number">The id number of the AdResolver entry to be referenced</param>
            ///<returns type="Object">adResolverEntry object reference</returns>
            var entry = pool[idNumber - poolBaseId], 
                ex;
            if (!entry) {
                ex = new PLAYER_SEQUENCER.AdResolverError('invalid getEntryFromId Id: ' + idNumber.toString());
                throw ex;
            }
            return entry;
        },

        testProbe_toJSON: function () {
            ///<summary>For testing purposes, return JSON string of the entire AdResolver entry pool</summary>
            ///<returns type="String">JSON of the entire playbackSegment pool</returns>
            return '{' + JSON.stringify(pool) + ',"poolBaseId":' + poolBaseId.toString() + ',"poolNextEntryId":' + poolNextEntryId.toString() + '}';
        },

        testProbe_reset: function () {
            ///<summary>For testing purposes, reset the entire AdResolver entry pool</summary>
            pool = [];
            poolBaseId = poolNextEntryId; // the segmentId of the zeroth pool element
        }
    };
}());


// -------------------------
// The AdResolver Handler
// -------------------------
// Note: The purpose of this object is to provide an API for AdResolver XML documents.
//       This can be a singleton since the objects are independent.
//
PLAYER_SEQUENCER.theAdResolver = (function () {
"use strict";
    // private variables
    var myDOMParser = new DOMParser(),
        myAdResolverEntryPool = PLAYER_SEQUENCER.theAdResolverEntryPool,

    // private methods

    // Note: When dealing with element names, only the "localName" (without any namespace identifier) is used
    //       instead of the "nodeName" (fully qualified) since the namespace identifier is arbitrary.
    //       The fully qualified name for attributes is always given in the results list.

    myDocNodeFromElementPath = function(parsedDocument, eltPathNameArray) {
        ///<summary>Walk the parsedDocument tree following the path of elements provided in eltPathNameArray and return the document node found.</summary>
        ///<param name="eltPathNameArray" type="Array">Array of strings containing eltName:index where eltName is element name (or "*"" for wildcard) and index is the ordinal of the Element child</param>
        ///<returns type="Object">A reference to the node in the document</returns>
        var paramIx,
            currentDocNode = parsedDocument,
            currentPathElt,
            nodeIx,
            nodeCount;

        for (paramIx = 0; paramIx < eltPathNameArray.length; paramIx += 1) {
            currentPathElt = eltPathNameArray[paramIx].split(':');
            nodeCount = currentDocNode.childNodes.length;
            for (nodeIx = 0; nodeIx < nodeCount; nodeIx += 1) {
                if (Element.prototype.isPrototypeOf(currentDocNode.childNodes[nodeIx]) && 
                    ( currentPathElt[0] === '*' || currentPathElt[0] === currentDocNode.childNodes[nodeIx].localName)) {
                    if (currentPathElt.length === 1 || currentPathElt[1] < 1) {
                        currentDocNode = currentDocNode.childNodes[nodeIx];
                        break;
                    }
                    if (currentPathElt.length > 1) {
                        currentPathElt[1] -= 1;
                    }
                }
            }
            if (nodeIx === nodeCount) {
                throw new PLAYER_SEQUENCER.AdResolverError("Failed to find path " + JSON.stringify(eltPathNameArray));
            }
        }

        return currentDocNode;
    },

    myArrayFromDocNode = function(docNode, nodeNameFilter) {
        ///<summary>Create object from next level elements and their attributes.</summary>
        ///<param name="docNode" type="Object">document sub-node to use</param>
        ///<param name="nodeNameFilter" type="String">Element name filter</param>
        ///<returns type="Array">Array of Element 'name', 'value' and 'attrs' properties</returns>
        var result = [],
            docChildIndex,
            contentIndex,
            eltNode,
            childEltNames,
            resultObj;

        for (docChildIndex = 0; docChildIndex < docNode.childNodes.length; docChildIndex += 1) {
            eltNode = docNode.childNodes[docChildIndex];
            if (Element.prototype.isPrototypeOf(eltNode) && (!nodeNameFilter || eltNode.localName === nodeNameFilter)) {
                if (nodeNameFilter) {
                    resultObj = {};
                } else {
                    resultObj = { name: eltNode.localName };
                }
                // CDATA text
                for (contentIndex = 0; contentIndex < eltNode.childNodes.length; contentIndex += 1) {
                    if (CDATASection.prototype.isPrototypeOf(eltNode.childNodes[contentIndex])) {
                        resultObj.value = eltNode.childNodes[contentIndex].nodeValue;
                        break;
                    }
                }
                // If no CDATA
                if (contentIndex === eltNode.childNodes.length) {
                    // Count the number of contained elements
                    childEltNames = [];
                    for (contentIndex = 0; contentIndex < eltNode.childNodes.length; contentIndex += 1) {
                        if (Element.prototype.isPrototypeOf(eltNode.childNodes[contentIndex])) {
                            childEltNames.push(eltNode.childNodes[contentIndex].localName);
                        }
                    }
                    // If contained elements just give count
                    if (childEltNames.length > 0) {
                        if (nodeNameFilter) {
                            resultObj.elements = childEltNames;
                        } else {
                            resultObj.elements = childEltNames.length;
                        }
                    } else {
                        // give value of first Text element that is not just a newline // TODO: should be: is not just white space
                        for (contentIndex = 0; contentIndex < eltNode.childNodes.length; contentIndex += 1) {
                            if (Text.prototype.isPrototypeOf(eltNode.childNodes[contentIndex])) {
                                if (eltNode.childNodes[contentIndex].nodeValue !== '\n') {
                                    resultObj.value = eltNode.firstChild.nodeValue;
                                    break;
                                }                            
                            }
                        }
                    }
                }
                // attributes
                if (eltNode.attributes && eltNode.attributes.length > 0) {
                    resultObj.attrs = {};
                    for (contentIndex = 0; contentIndex < eltNode.attributes.length; contentIndex += 1) {
                        resultObj.attrs[eltNode.attributes[contentIndex].nodeName] = eltNode.attributes[contentIndex].nodeValue;
                    }
                }
                result.push(resultObj);
            }
        }
        return result;
    },

    myArrayOfChildrenFromDocNode = function(docNode, parentName) {
        ///<summary>Create object from next level elements and their attributes.</summary>
        ///<param name="docNode" type="Object">document sub-node to use</param>
        ///<returns type="Array">Array of type, parentAttrs, and elements (with 'name', 'value' and 'attrs' properties)</returns>
        var 
        result = [],
            nodeObj,
            docNodeParent,
            docNodeChild,
            contentIndex,
            parentIndex,
            childIndex,
            childElements,
            parentOrdinal = 0;

        for (parentIndex = 0; parentIndex < docNode.childNodes.length; parentIndex += 1) {
            docNodeParent = docNode.childNodes[parentIndex];
            if (Element.prototype.isPrototypeOf(docNodeParent) && docNodeParent.localName === parentName) {
                for (childIndex = 0; childIndex < docNodeParent.childNodes.length; childIndex += 1) {
                    docNodeChild = docNodeParent.childNodes[childIndex];
                    if (Element.prototype.isPrototypeOf(docNodeChild)) {
                        nodeObj = { type: docNodeChild.localName };
                        // Parent attributes
                        if (docNodeParent.attributes && docNodeParent.attributes.length > 0) {
                            nodeObj.parentAttrs = {};
                            for (contentIndex = 0; contentIndex < docNodeParent.attributes.length; contentIndex += 1) {
                                nodeObj.parentAttrs[docNodeParent.attributes[contentIndex].nodeName] = docNodeParent.attributes[contentIndex].nodeValue;
                            }
                        }
                        // Child attributes
                        if (docNodeChild.attributes && docNodeChild.attributes.length > 0) {
                            nodeObj.attrs = {};
                            for (contentIndex = 0; contentIndex < docNodeChild.attributes.length; contentIndex += 1) {
                                nodeObj.attrs[docNodeChild.attributes[contentIndex].nodeName] = docNodeChild.attributes[contentIndex].nodeValue;
                            }
                        }
                        // Child elements if any, else CDATA section if one.
                        childElements = myArrayFromDocNode(docNodeChild);
                        if (childElements.length > 0) {
                            nodeObj.elements = childElements;
                        } else {
                            for (contentIndex = 0; contentIndex < docNodeChild.childNodes.length; contentIndex += 1) {
                                if (CDATASection.prototype.isPrototypeOf(docNodeChild.childNodes[contentIndex])) {
                                    nodeObj.value = docNodeChild.childNodes[contentIndex].nodeValue;
                                    break;
                                }
                            }
                        }
                        result.push(nodeObj);
                        break;
                    }
                }
                parentOrdinal += 1;
            }
        }
        return result;
    },

    // ---------------------------------
    // public methods
    // ---------------------------------

    // Note: Error codes are in VAST 3.0 spec: 2.4.2.3 and VMAP 1.0 spec: 2.5

    publicAPI = {
        vast: { // === VAST Parsed document information access ===

            createEntry: function (aManifest) {
                ///<summary>Create a AdResolverEntry by parsing an XML string or using a DOM Document.</summary>
                ///<param name="aManifest" type="String">The manifest as an XML string</param>
                ///<param name="aManifest" type="Object">The manifest as an object derived from Document</param>
                ///<returns type="Number">The idNumber for the AdResolverEntry that was created. Throws AdResolverError if invalid AdResolver document.</returns>
                var parsedDocument;

                if (typeof aManifest === 'string') {
                    parsedDocument = myDOMParser.parseFromString(aManifest, "application/xml");
                }
                else if (Document.prototype.isPrototypeOf(aManifest) || Element.prototype.isPrototypeOf(aManifest)) {
                    parsedDocument = aManifest;
                }
                else {
                    throw new PLAYER_SEQUENCER.AdResolverError('vast.createEntry parameter invalid! ' + aManifest.toString());
                }

                // Assert the top level element is <VAST> and it contains at least one <Ad>.
                myDocNodeFromElementPath(parsedDocument, ['VAST', 'Ad']);
                // myDocNodeFromElementPath throws an exception if path not found

                return myAdResolverEntryPool.createEntry(parsedDocument).idNumber;
            },

            getAdList: function (params) {
                ///<summary>Release the AdResolverEntry obtained from the create functions</summary>
                ///<param name="params" type="Object">An object with "entryId" (result of the create function)</param>
                ///<returns type="Array">Array of objects for each 'Ad': { type: "InLine" | "Wrapper", attrs: { Ad attrs }, elements: [<childElts>] }</returns>
                var entry = myAdResolverEntryPool.getEntryFromId(params.entryId),
                    docNodeVAST = myDocNodeFromElementPath(entry.parsedDocument, ['VAST']);

                return myArrayOfChildrenFromDocNode(docNodeVAST, 'Ad');
            },

            getCreativeList: function (params) {
                ///<summary>Get a list of Creative entries given Ad ordinal number.</summary>
                ///<param name="params" type="Object">An object with "entryId" (result of the create function), "adOrdinal" (which of multiple <Ad>) and "adType" from Ad list</param>
                ///<returns type="Array">Array of objects { type (Linear/Companion/NonLinear), Creative attributes }</returns>
                var entry = myAdResolverEntryPool.getEntryFromId(params.entryId),
                    adIndex = params.adOrdinal || 0,
                    docNodeCreatives;

                docNodeCreatives = myDocNodeFromElementPath(entry.parsedDocument,
                    [
                        'VAST',
                        'Ad:' + adIndex.toString(),
                        params.adType,
                        'Creatives'
                    ]);

                return myArrayOfChildrenFromDocNode(docNodeCreatives, 'Creative');
            },

            getLinearTrackingEventsList: function (params) {
                ///<summary>Get a list of TrackingEvents entries given Ad and Creative ordinal numbers.</summary>
                ///<param name="params" type="Object">An object with "entryId" (result of the create function), "adOrdinal" (which of multiple <Ad>), and "creativeOrdinal" (which of multiple <Creative></param>
                ///<returns type="Array">An array of objects with a 'name' string (should be "Tracking"), 'value' string with the CDATA URL string, and an 'attrs' object containing the <MediaFile> attributes</returns>
                var entry = myAdResolverEntryPool.getEntryFromId(params.entryId),
                    adIndex = params.adOrdinal || 0,
                    creativeIndex = params.creativeOrdinal || 0,
                    docTrackingEvents;

                docTrackingEvents = myDocNodeFromElementPath(entry.parsedDocument,
                    [
                        'VAST',
                        'Ad:' + adIndex.toString(),
                        '*', // allows either InLine or Wrapper
                        'Creatives',
                        'Creative:' + creativeIndex.toString(),
                        'Linear',
                        'TrackingEvents'
                    ]);

                return myArrayFromDocNode(docTrackingEvents);
            },

            getVideoClicksList: function (params) {
                ///<summary>Get a list of VideoClicks entries given Ad and Creative ordinal numbers.</summary>
                ///<param name="params" type="Object">An object with "entryId" (result of the create function), "adOrdinal" (which of multiple <Ad>), and "creativeOrdinal" (which of multiple <Creative></param>
                ///<returns type="Array">An array of objects with a 'name' string, 'value' string with the CDATA URL string, and an 'attrs' object containing the <MediaFile> attributes</returns>
                var entry = myAdResolverEntryPool.getEntryFromId(params.entryId),
                    adIndex = params.adOrdinal || 0,
                    creativeIndex = params.creativeOrdinal || 0,
                    docVideoClicks;

                docVideoClicks = myDocNodeFromElementPath(entry.parsedDocument,
                    [
                        'VAST',
                        'Ad:' + adIndex.toString(),
                        '*', // allows either InLine or Wrapper
                        'Creatives',
                        'Creative:' + creativeIndex.toString(),
                        'Linear',
                        'VideoClicks'
                    ]);

                return myArrayFromDocNode(docVideoClicks);
            },

            getIconsList: function (params) {
                ///<summary>Get a list of Icons entries given Ad and Creative ordinal numbers.</summary>
                ///<param name="params" type="Object">An object with "entryId" (result of the create function), "adOrdinal" (which of multiple <Ad>), and "creativeOrdinal" (which of multiple <Creative></param>
                ///<returns type="Array">An array of Icon objects</returns>
                var entry = myAdResolverEntryPool.getEntryFromId(params.entryId),
                    adIndex = params.adOrdinal || 0,
                    creativeIndex = params.creativeOrdinal || 0,
                    docIcons;

                docIcons = myDocNodeFromElementPath(entry.parsedDocument,
                    [
                        'VAST',
                        'Ad:' + adIndex.toString(),
                        '*', // allows either InLine or Wrapper
                        'Creatives',
                        'Creative:' + creativeIndex.toString(),
                        'Linear',
                        'Icons'
                    ]);

                return myArrayOfChildrenFromDocNode(docIcons, 'Icon');
            },

            getMediaFileList: function (params) {
                ///<summary>Get a list of MediaFile entries given Ad and Creative ordinal numbers.</summary>
                ///<param name="params" type="Object">An object with "entryId" (result of the create function), "adOrdinal" (which of multiple <Ad>), and "creativeOrdinal" (which of multiple <Creative></param>
                ///<returns type="Object">An array of objects with a 'name' string (should be "MediaFile"), 'value' string with the CDATA URL string, and an 'attrs' object containing the <MediaFile> attributes</returns>
                var entry = myAdResolverEntryPool.getEntryFromId(params.entryId),
                    adIndex = params.adOrdinal || 0,
                    creativeIndex = params.creativeOrdinal || 0,
                    docNodeMediaFiles;

                docNodeMediaFiles = myDocNodeFromElementPath(entry.parsedDocument,
                    [
                        'VAST',
                        'Ad:' + adIndex.toString(),
                        'InLine',
                        'Creatives',
                        'Creative:' + creativeIndex.toString(),
                        'Linear',
                        'MediaFiles'
                    ]);

                return myArrayFromDocNode(docNodeMediaFiles);
            },

            getCompanionAdsList: function (params) {
                ///<summary>Get a list of CompanionAds entries given Ad and Creative ordinal numbers.</summary>
                ///<param name="params" type="Object">An object with "entryId" (result of the create function), "adOrdinal" (which of multiple <Ad>), and "creativeOrdinal" (which of multiple <Creative></param>
                ///<returns type="Array">An array of Companion objects</returns>
                var entry = myAdResolverEntryPool.getEntryFromId(params.entryId),
                    adIndex = params.adOrdinal || 0,
                    creativeIndex = params.creativeOrdinal || 0,
                    docCompanionAds;

                docCompanionAds = myDocNodeFromElementPath(entry.parsedDocument,
                    [
                        'VAST',
                        'Ad:' + adIndex.toString(),
                        '*', // allows either InLine or Wrapper
                        'Creatives',
                        'Creative:' + creativeIndex.toString(),
                        'CompanionAds'
                    ]);

                return myArrayOfChildrenFromDocNode(docCompanionAds, 'Companion');
            },

            getNonLinearAdsList: function (params) {
                ///<summary>Get a list of NonLinearAds entries given Ad and Creative ordinal numbers.</summary>
                ///<param name="params" type="Object">An object with "entryId" (result of the create function), "adOrdinal" (which of multiple <Ad>), and "creativeOrdinal" (which of multiple <Creative></param>
                ///<returns type="Array">An array of Companion objects</returns>
                var entry = myAdResolverEntryPool.getEntryFromId(params.entryId),
                    adIndex = params.adOrdinal || 0,
                    creativeIndex = params.creativeOrdinal || 0,
                    docNonLinearAds;

                docNonLinearAds = myDocNodeFromElementPath(entry.parsedDocument,
                    [
                        'VAST',
                        'Ad:' + adIndex.toString(),
                        '*', // allows either InLine or Wrapper
                        'Creatives',
                        'Creative:' + creativeIndex.toString(),
                        'NonLinearAds'
                    ]);

                return myArrayOfChildrenFromDocNode(docNonLinearAds, 'Companion');
            },
        },

        vmap: { // === VMAP Parsed document information access ===

            createEntry: function (aManifest) {
                ///<summary>Create a AdResolverEntry by parsing an XML string or using a DOM Document.</summary>
                ///<param name="aManifest" type="String">The manifest as an XML string</param>
                ///<param name="aManifest" type="Object">The manifest as an object derived from Document</param>
                ///<returns type="Number">The idNumber for the AdResolverEntry that was created. Throws AdResolverError if invalid AdResolver document.</returns>
                var parsedDocument;

                if (typeof aManifest === 'string') {
                    parsedDocument = myDOMParser.parseFromString(aManifest, "application/xml");
                }
                else if (Document.prototype.isPrototypeOf(aManifest)) {
                    parsedDocument = aManifest;
                }
                else {
                    throw new PLAYER_SEQUENCER.AdResolverError('vmap.createEntry parameter invalid! ' + aManifest.toString());
                }

                // Assert the top level element is <VMAP> and it contains at least one <AdBreak>.
                myDocNodeFromElementPath(parsedDocument, ['VMAP', 'AdBreak']);
                // myDocNodeFromElementPath throws an exception if path not found

                return myAdResolverEntryPool.createEntry(parsedDocument).idNumber;
            },

            getAdBreakList: function (params) {
                ///<summary>Get a list of AdBreak items</summary>
                ///<param name="params" type="Object">An object with "entryId" (result of the createEntry function)</param>
                ///<returns type="Array">Array of objects, one for each 'AdBreak' element: [{elements:[string array of next level elements],attrs:{set of attribute name:value pairs}]</returns>
                var entry = myAdResolverEntryPool.getEntryFromId(params.entryId),
                    docNodeVMAP = myDocNodeFromElementPath(entry.parsedDocument, ['VMAP']);

                return myArrayFromDocNode(docNodeVMAP, 'AdBreak');
            },

            getAdSource: function (params) {
                ///<summary>Get the AdSource item for a given AdBreak</summary>
                ///<param name="params" type="Object">An object with "entryId" (result of the createEntry function) and "adBreakOrdinal" (index into AdBreakList)</param>
                ///<returns type="Object">An Object containing: {type:(enum VASTData,CustomAdData,AdTagURI),attrs:{set of attribute name:value pairs},value</returns>
                var entry = myAdResolverEntryPool.getEntryFromId(params.entryId),
                    adBreakIndex = params.adBreakOrdinal || 0,
                    docNode = myDocNodeFromElementPath(entry.parsedDocument, ['VMAP', 'AdBreak:' + adBreakIndex.toString()]);

                return myArrayOfChildrenFromDocNode(docNode, 'AdSource');
            },

            createVASTEntryFromAdBreak: function (params) {
                ///<summary>Create a VASTEntry for a given AdBreak which is assumed to contain an AdSource/VASTData element.</summary>
                ///<param name="params" type="Object">An object with "entryId" (result of the createEntry function) and "adBreakOrdinal" (index into AdBreakList)</param>
                ///<returns type="Number">A VASTEntry idNumber</returns>
                var entry = myAdResolverEntryPool.getEntryFromId(params.entryId),
                    adBreakIndex = params.adBreakOrdinal || 0,
                    docNode;

                    docNode = myDocNodeFromElementPath(entry.parsedDocument, 
                        [
                            'VMAP', 
                            'AdBreak:' + adBreakIndex.toString(), 
                            'AdSource', 
                            'VASTData'
                        ]);

                return publicAPI.vast.createEntry(docNode);
            },

            getTrackingEventsList: function (params) {
                ///<summary>Get the list of Tracking elements for the TrackingEvents element in a given AdBreak</summary>
                ///<param name="params" type="Object">An object with "entryId" (result of the createEntry function) and "adBreakOrdinal" (index into AdBreakList)</param>
                ///<returns type="Array">An array of Tracking element objects: { value, attrs }</returns>
                var entry = myAdResolverEntryPool.getEntryFromId(params.entryId),
                    adBreakIndex = params.adBreakOrdinal || 0,
                    docNode = myDocNodeFromElementPath(entry.parsedDocument, ['VMAP', 'AdBreak:' + adBreakIndex.toString(), 'TrackingEvents']);

                return myArrayFromDocNode(docNode, 'Tracking');
            },

            getExtensionsList: function (params) {
                ///<summary>Get the list of Extension elements for the Extensions element in a given AdBreak</summary>
                ///<param name="params" type="Object">An object with "entryId" (result of the createEntry function) and "adBreakOrdinal" (index into AdBreakList)</param>
                ///<returns type="Array">An array of Extension element objects: {elements, attrs}</returns>
                var entry = myAdResolverEntryPool.getEntryFromId(params.entryId),
                    adBreakIndex = params.adBreakOrdinal || 0,
                    docNode = myDocNodeFromElementPath(entry.parsedDocument, ['VMAP', 'AdBreak:' + adBreakIndex.toString(), 'Extensions']);

                return myArrayFromDocNode(docNode, 'Extension');
            },

        },

        // === Generic element access and entry release===

        getElementListFromPath: function (params) {
            ///<summary>Get an arbitrary element list given a document tree path</summary>
            ///<param name="params" type="Object">An object with "entryId" (result of the create function) and "path" (array of Element name:count strings) optionally filtered by "nodeName"</param>
            ///<returns type="Array">An array of objects representing the elements within the node specified. </returns>
            var entry = myAdResolverEntryPool.getEntryFromId(params.entryId),
                docNode = myDocNodeFromElementPath(entry.parsedDocument, params.path);

            return myArrayFromDocNode(docNode, params.nodeName);
        },

        releaseEntry: function (adResolverEntryIdNumber) {
            ///<summary>Release the AdResolverEntry obtained from the create functions</summary>
            ///<param name="params" type="Number">The AdResolverEntry id number (result of the create function)</param>
            myAdResolverEntryPool.releaseEntry(adResolverEntryIdNumber);
        },

        // === JSON thunk ===
        runJSON: function (paramsJSON) {
            ///<summary>Invoke theAdResolver methods using a JSON string and returning the result as a JSON string.</summary>
            ///<param name="paramsJSON" type="String">The method name and params expressed in a JSON string. There must be a top level property "func" string with the name of the method to invoke. Method params can either be all top level or within a containing "params" object.</param>
            ///<returns type="String">The method results expressed is a JSON string. If an exception was thrown, a top level object "EXCEPTION" will contain standard Error fields.</returns>

            var funcArray, params, result, stackArray, stackAsJSON, i;

            try {
                params = JSON.parse(paramsJSON);

                if (!params || (typeof params.func !== 'string')) {
                    throw new PLAYER_SEQUENCER.AdResolverError('runJSON func property missing or not a string');
                }

                funcArray = params.func.split('.');
                if (funcArray.length > 1) {
                    if (params.params) {
                        result = PLAYER_SEQUENCER.theAdResolver[funcArray[0]][funcArray[1]](params.params);
                    }
                    else {
                        result = PLAYER_SEQUENCER.theAdResolver[funcArray[0]][funcArray[1]](params);
                    }
                } else {
                    if (params.params) {
                        result = PLAYER_SEQUENCER.theAdResolver[params.func](params.params);
                    }
                    else {
                        result = PLAYER_SEQUENCER.theAdResolver[params.func](params);
                    }
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

    return publicAPI;
}());
