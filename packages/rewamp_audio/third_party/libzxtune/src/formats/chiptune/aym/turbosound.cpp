/**
* 
* @file
*
* @brief  TurboSound container support implementation
*
* @author vitamin.caig@gmail.com
*
**/

//local includes
#include "turbosound.h"
#include "protracker3.h"
#include "formats/chiptune/container.h"
//common includes
#include <byteorder.h>
//library includes
#include <binary/format_factories.h>
#include <binary/typed_container.h>
#include <math/numeric.h>
//std includes
#include <cstring>
//boost includes
#include <boost/make_shared.hpp>
//text includes
#include <formats/text/chiptune.h>

namespace Formats
{
namespace Chiptune
{
  namespace TurboSound
  {
    const std::size_t MIN_SIZE = 256;
    const std::size_t MAX_MODULE_SIZE = 16384;
    const std::size_t MAX_SIZE = MAX_MODULE_SIZE * 2;

#ifdef USE_PRAGMA_PACK
#pragma pack(push,1)
#endif
    PACK_PRE struct Footer
    {
      uint8_t ID1[4];//'PT3!' or other type
      ruint16_t Size1;
      uint8_t ID2[4];//same
      ruint16_t Size2;
      uint8_t ID3[4];//'02TS'
    } PACK_POST;
#ifdef USE_PRAGMA_PACK
#pragma pack(pop)
#endif

    const uint8_t TS_ID[] = {'0', '2', 'T', 'S'};

    BOOST_STATIC_ASSERT(sizeof(Footer) == 16);

    const std::string FOOTER_FORMAT(
      "%0xxxxxxx%0xxxxxxx%0xxxxxxx21"  // uint8_t ID1[4];//'PT3!' or other type
      "?%00xxxxxx"                     // uint16_t Size1;
      "%0xxxxxxx%0xxxxxxx%0xxxxxxx21"  // uint8_t ID2[4];//same
      "?%00xxxxxx"                     // uint16_t Size2;
      "'0'2'T'S"                       // uint8_t ID3[4];//'02TS'
    );

    class StubBuilder : public Builder
    {
    public:
      virtual void SetFirstSubmoduleLocation(std::size_t /*offset*/, std::size_t /*size*/) {}
      virtual void SetSecondSubmoduleLocation(std::size_t /*offset*/, std::size_t /*size*/) {}
    };

    class ModuleTraits
    {
    public:
      ModuleTraits(const Binary::Data& data, std::size_t footerOffset)
        : FooterOffset(footerOffset)
        , Foot(footerOffset != data.Size() ? safe_ptr_cast<const Footer*>(static_cast<const uint8_t*>(data.Start()) + footerOffset) : 0)
        , FirstSize(Foot ? fromLE(Foot->Size1) : 0)
        , SecondSize(Foot ? fromLE(Foot->Size2) : 0)
      {
      }

      bool Matched() const
      {
        return Foot != 0 && FooterOffset == FirstSize + SecondSize && Math::InRange(FooterOffset, MIN_SIZE, MAX_SIZE);
      }

      std::size_t NextOffset() const
      {
        if (Foot == 0)
        {
          return FooterOffset;
        }
        const std::size_t totalSize = FirstSize + SecondSize;
        if (totalSize < FooterOffset)
        {
          return FooterOffset - totalSize;
        }
        else
        {
          return FooterOffset + sizeof(*Foot);
        }
      }

      std::size_t GetFirstModuleSize() const
      {
        return FirstSize;
      }

      std::size_t GetSecondModuleSize() const
      {
        return SecondSize;
      }

      std::size_t GetTotalSize() const
      {
        return FooterOffset + sizeof(*Foot);
      }
    private:
      const std::size_t FooterOffset;
      const Footer* const Foot;
      const std::size_t FirstSize;
      const std::size_t SecondSize;
    };

    class FooterFormat : public Binary::Format
    {
    public:
      typedef boost::shared_ptr<const FooterFormat> Ptr;

      FooterFormat()
        : Delegate(Binary::CreateFormat(FOOTER_FORMAT))
      {
      }

      virtual bool Match(const Binary::Data& data) const
      {
        const ModuleTraits traits = GetTraits(data);
        return traits.Matched();
      }

      virtual std::size_t NextMatchOffset(const Binary::Data& data) const
      {
        const ModuleTraits traits = GetTraits(data);
        return traits.NextOffset();
      }

      ModuleTraits GetTraits(const Binary::Data& data) const
      {
        return ModuleTraits(data, Delegate->NextMatchOffset(data));
      }
    private:
      const Binary::Format::Ptr Delegate;
    };

    class DecoderImpl : public Decoder
    {
    public:
      DecoderImpl()
        : Format(boost::make_shared<FooterFormat>())
      {
      }

      virtual String GetDescription() const
      {
        return Text::TURBOSOUND_DECODER_DESCRIPTION;
      }

      virtual Binary::Format::Ptr GetFormat() const
      {
        return Format;
      }

      virtual bool Check(const Binary::Container& rawData) const
      {
        return Format->Match(rawData);
      }

      virtual Formats::Chiptune::Container::Ptr Decode(const Binary::Container& rawData) const
      {
        Builder& stub = GetStubBuilder();
        return Parse(rawData, stub);
      }

      virtual Formats::Chiptune::Container::Ptr Parse(const Binary::Container& rawData, Builder& target) const
      {
        const ModuleTraits& traits = Format->GetTraits(rawData);

        if (!traits.Matched())
        {
          return Formats::Chiptune::Container::Ptr();
        }

        target.SetFirstSubmoduleLocation(0, traits.GetFirstModuleSize());
        target.SetSecondSubmoduleLocation(traits.GetFirstModuleSize(), traits.GetSecondModuleSize());

        const std::size_t usedSize = traits.GetTotalSize();
        const Binary::Container::Ptr subData = rawData.GetSubcontainer(0, usedSize);
        //use whole container as a fixed data
        return CreateCalculatingCrcContainer(subData, 0, usedSize);
      }
    private:
      const FooterFormat::Ptr Format;
    };

    Builder& GetStubBuilder()
    {
      static StubBuilder stub;
      return stub;
    }

    Decoder::Ptr CreateDecoder()
    {
      return boost::make_shared<DecoderImpl>();
    }

    //REWAMP: TurboSound in the Vortex TEXT format.
    //
    //A TS pair saved as text is just the two modules concatenated — VT II documents
    //the fact by telling you to build one with "copy Module1.txt+Module2.txt"
    //(History.txt, 05/18/2007). There is no footer to key on, so the two spans are
    //found by MEASURING: the text decoder reports how far the first module reaches,
    //and the second starts at the next [Module] line after it. Without this a 6-voice
    //file comes out as two 3-voice modules and only half the music is ever heard.
    const std::string TEXT_MODULE_FORMAT(
      "'['M'o'd'u'l'e']"
    );

    const std::size_t MIN_TEXT_SIZE = 256;

    class TextDecoder : public Decoder
    {
    public:
      TextDecoder()
        : Format(Binary::CreateFormat(TEXT_MODULE_FORMAT, MIN_TEXT_SIZE))
        , Submodule(ProTracker3::VortexTracker2::CreateDecoder())
      {
      }

      virtual String GetDescription() const
      {
        return Text::TURBOSOUND_DECODER_DESCRIPTION;
      }

      virtual Binary::Format::Ptr GetFormat() const
      {
        return Format;
      }

      virtual bool Check(const Binary::Container& rawData) const
      {
        return Format->Match(rawData);
      }

      virtual Formats::Chiptune::Container::Ptr Decode(const Binary::Container& rawData) const
      {
        Builder& stub = GetStubBuilder();
        return Parse(rawData, stub);
      }

      virtual Formats::Chiptune::Container::Ptr Parse(const Binary::Container& rawData, Builder& target) const
      {
        if (!Format->Match(rawData))
        {
          return Formats::Chiptune::Container::Ptr();
        }
        const Formats::Chiptune::Container::Ptr first = Submodule->Decode(rawData);
        if (!first || !first->Size())
        {
          return Formats::Chiptune::Container::Ptr();
        }
        const std::size_t secondOffset = FindNextModule(rawData, first->Size());
        if (!secondOffset)
        {
          //A single text module: leave it to the plain TXT plugin.
          return Formats::Chiptune::Container::Ptr();
        }
        const Binary::Container::Ptr rest = rawData.GetSubcontainer(secondOffset, rawData.Size() - secondOffset);
        const Formats::Chiptune::Container::Ptr second = rest ? Submodule->Decode(*rest) : Formats::Chiptune::Container::Ptr();
        if (!second || !second->Size())
        {
          return Formats::Chiptune::Container::Ptr();
        }
        target.SetFirstSubmoduleLocation(0, first->Size());
        target.SetSecondSubmoduleLocation(secondOffset, second->Size());

        const std::size_t usedSize = secondOffset + second->Size();
        const Binary::Container::Ptr subData = rawData.GetSubcontainer(0, usedSize);
        return CreateCalculatingCrcContainer(subData, 0, usedSize);
      }
    private:
      //The header must sit at the start of a line, so a "[Module]" that happens to
      //appear inside a title or a comment cannot split the file.
      static std::size_t FindNextModule(const Binary::Data& data, std::size_t from)
      {
        static const char MARKER[] = "[Module]";
        const std::size_t markerSize = sizeof(MARKER) - 1;
        const uint8_t* const begin = static_cast<const uint8_t*>(data.Start());
        const std::size_t size = data.Size();
        for (std::size_t pos = from; pos + markerSize <= size; ++pos)
        {
          if (0 != std::memcmp(begin + pos, MARKER, markerSize))
          {
            continue;
          }
          if (pos && begin[pos - 1] != '\n')
          {
            continue;
          }
          return pos;
        }
        return 0;
      }
    private:
      const Binary::Format::Ptr Format;
      const ProTracker3::Decoder::Ptr Submodule;
    };

    Decoder::Ptr CreateTextDecoder()
    {
      return boost::make_shared<TextDecoder>();
    }
  }//namespace TurboSound

  Decoder::Ptr CreateTurboSoundDecoder()
  {
    return TurboSound::CreateDecoder();
  }
}//namespace Chiptune
}//namespace Formats
