//
// Flambe - Rapid game development
// https://github.com/aduros/flambe/blob/master/LICENSE.txt

package flambe.platform.flash;

import flash.display.Bitmap;
import flash.display.Loader;
import flash.errors.Error;
import flash.events.ErrorEvent;
import flash.events.Event;
import flash.events.IEventDispatcher;
import flash.events.IOErrorEvent;
import flash.events.ProgressEvent;
import flash.events.SecurityErrorEvent;
import flash.media.Sound;
import flash.net.URLLoader;
import flash.net.URLRequest;
import flash.system.Capabilities;
import flash.system.LoaderContext;

import flambe.asset.AssetEntry;
import flambe.asset.Manifest;

class FlashAssetPackLoader extends BasicAssetPackLoader
{
    public function new (platform :FlashPlatform, manifest :Manifest)
    {
        super(platform, manifest);
    }

    override private function loadEntry (url :String, entry :AssetEntry)
    {
        var req = new URLRequest(url);

        // The dispatcher to listen for progress, completion and error events
        var dispatcher :IEventDispatcher;

        // The function called to create the asset after its content loads
        var create :Void -> Dynamic;

        switch (entry.type) {
        case Image:
            var loader = new Loader();
            dispatcher = loader.contentLoaderInfo;
            create = function () {
                var bitmap :Bitmap = cast loader.content;
                return _platform.getRenderer().createTexture(bitmap.bitmapData);
            };

            var ctx = new LoaderContext();
            ctx.checkPolicyFile = true;
            ctx.allowCodeImport = false;
            ctx.imageDecodingPolicy = ON_LOAD;
            loader.load(req, ctx);

        case Audio:
            var sound = new Sound(req);
            dispatcher = sound;
            create = function () return new FlashSound(sound);

        case Data:
            var urlLoader = new URLLoader(req);
            dispatcher = urlLoader;
            create = function () return urlLoader.data;
        }

        var events = new EventGroup();
        events.addListener(dispatcher, ProgressEvent.PROGRESS, function (event :ProgressEvent) {
            handleProgress(entry, cast event.bytesLoaded);
        });
        events.addDisposingListener(dispatcher, Event.COMPLETE, function (_) {
            var asset;
            try {
                asset = create();
            } catch (error :Error) {
                handleError(entry, error.message);
                return;
            }
            if (asset != null) {
                handleLoad(entry, asset);
            } else {
                // Assume this is a failed createTexture()
                handleTextureError(entry);
            }
        });

        var onError = function (event :ErrorEvent) {
            handleError(entry, event.text);
        };
        events.addDisposingListener(dispatcher, IOErrorEvent.IO_ERROR, onError);
        events.addDisposingListener(dispatcher, SecurityErrorEvent.SECURITY_ERROR, onError);
    }

    override private function getImageFormats (fn :Array<String> -> Void)
    {
        fn(["jxr", "png", "jpg", "gif"]);
    }

    override private function getAudioFormats (fn :Array<String> -> Void)
    {
        // TODO(bruno): Flash actually has an m4a decoder, but it's only accessible through the
        // horrendous NetStream API and not good old flash.media.Sound
        fn(Capabilities.hasAudio && Capabilities.hasMP3 ? ["mp3"] : []);
    }
}
