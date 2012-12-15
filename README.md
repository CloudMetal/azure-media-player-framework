Windows Azure Media Player Framework preview for iOS
======
This Windows Azure Media Services iOS client library makes it easy for iPhone, iPad, and iPod Touch media application developers to create rich, dynamic client applications that dynamically create and play complex audio/video playlists. 
For example, applications that display sports content can easily insert advertisements wherever the opportunity arises and control how often those advertisements appear even when the main content is rewound. 
Educational applications can use the same functionality, for example, to create content in which the main lectures have asides, or sidebars, before returning to the main content.

Typically it is relatively complex to build an application that can create content streams that result from an interaction between the application and its user. Normally, you must create the entire stream from scratch and store it, in advance, on the server. 
Using the IOS Media Player Framework, you can:

* Schedule content streams in advance on the client device.
* Schedule pre-roll advertisements or inserts.
* Schedule post-roll advertisements or inserts.
* Schedule mid-roll advertisements or inserts. 
* Control whether the mid-roll advertisement or insert plays each time the content timeline is rewound or whether it only plays once and then removes itself from the playlist.
* Dynamically insert content directly into the timeline as a result of any event, whether the user pushed a button or the application received a notification from a service. For example, a news content program could send notifications of breaking news and the application could “pause” the main content to dynamically load a breaking news stream. 

Combining these features with the media playing facilities of iOS devices makes it possible to build very rich media experiences in a very short time with fewer resources.

This framework contains a SamplePlayer application that demonstrates how to build an iOS application that uses most of these features. 
It creates a content stream on the fly as well as enables the user to dynamically trigger an insert by pushing a button.
