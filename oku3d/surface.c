/* Prints what the FFmpeg build it runs against can read, one line per
 * item, so two builds can be compared line by line: every decoder with
 * its codec and whether avcodec_find_decoder picks it, the hardware
 * device types each decoder advertises, and every demuxer, input
 * protocol, parser, bitstream filter, muxer, filter, input device and
 * hardware device type. */

#include <stdio.h>

#include <libavcodec/avcodec.h>
#include <libavcodec/bsf.h>
#include <libavdevice/avdevice.h>
#include <libavfilter/avfilter.h>
#include <libavformat/avformat.h>
#include <libavutil/hwcontext.h>

int main(void)
{
    void *it = NULL;
    const AVCodec *codec;
    while ((codec = av_codec_iterate(&it))) {
        if (!av_codec_is_decoder(codec))
            continue;
        printf("decoder %s codec=%s%s%s\n", codec->name, avcodec_get_name(codec->id),
               (codec->capabilities & AV_CODEC_CAP_EXPERIMENTAL) ? " experimental" : "",
               avcodec_find_decoder(codec->id) == codec ? " picked" : "");
        for (int i = 0;; i++) {
            const AVCodecHWConfig *config = avcodec_get_hw_config(codec, i);
            if (!config)
                break;
            const char *type = av_hwdevice_get_type_name(config->device_type);
            printf("hwconfig %s %s\n", codec->name, type ? type : "none");
        }
    }

    it = NULL;
    const AVInputFormat *demuxer;
    while ((demuxer = av_demuxer_iterate(&it)))
        printf("demuxer %s\n", demuxer->name);

    it = NULL;
    const AVOutputFormat *muxer;
    while ((muxer = av_muxer_iterate(&it)))
        printf("muxer %s\n", muxer->name);

    it = NULL;
    const char *protocol;
    while ((protocol = avio_enum_protocols(&it, 0)))
        printf("protocol-in %s\n", protocol);

    it = NULL;
    const AVCodecParser *parser;
    while ((parser = av_parser_iterate(&it)))
        for (int i = 0; i < 7 && parser->codec_ids[i]; i++)
            printf("parser %s\n", avcodec_get_name(parser->codec_ids[i]));

    it = NULL;
    const AVBitStreamFilter *bsf;
    while ((bsf = av_bsf_iterate(&it)))
        printf("bsf %s\n", bsf->name);

    it = NULL;
    const AVFilter *filter;
    while ((filter = av_filter_iterate(&it)))
        printf("filter %s\n", filter->name);

    avdevice_register_all();
    const AVInputFormat *device = NULL;
    while ((device = av_input_video_device_next(device)))
        printf("indev %s\n", device->name);
    device = NULL;
    while ((device = av_input_audio_device_next(device)))
        printf("indev %s\n", device->name);

    enum AVHWDeviceType type = AV_HWDEVICE_TYPE_NONE;
    while ((type = av_hwdevice_iterate_types(type)) != AV_HWDEVICE_TYPE_NONE)
        printf("hwdevice %s\n", av_hwdevice_get_type_name(type));

    return 0;
}
