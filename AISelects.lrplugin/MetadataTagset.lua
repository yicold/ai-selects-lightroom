--[[
  MetadataTagset.lua
  ---------------------------------------------------------------------------
  Defines how AI Selects custom metadata fields appear in Lightroom's
  Metadata panel. Without this file, the fields exist in the catalog but
  are not visible in the UI.

  Registered in Info.lua via LrMetadataTagsetFactory.
--]]

return {
    title = 'AI Selects',
    id    = 'aiSelectsTagset',

    items = {
        -- Show basic EXIF info first so the panel is useful on its own
        'com.adobe.filename',
        'com.adobe.folder',
        'com.adobe.dateTimeOriginal',
        'com.adobe.dimensions',

        'com.adobe.separator',

        -- AI Selects scores (4 dimensions + composite)
        { 'io.github.gibbonsr4.ai-selects.aiSelectsComposite',    label = 'Composite Score'   },
        { 'io.github.gibbonsr4.ai-selects.aiSelectsTechnical',    label = 'Technical'         },
        { 'io.github.gibbonsr4.ai-selects.aiSelectsComposition',  label = 'Composition'       },
        { 'io.github.gibbonsr4.ai-selects.aiSelectsEmotion',      label = 'Emotion'           },
        { 'io.github.gibbonsr4.ai-selects.aiSelectsMoment',       label = 'Moment'            },

        'com.adobe.separator',

        -- Descriptive fields
        { 'io.github.gibbonsr4.ai-selects.aiSelectsContent',       label = 'Content'          },
        { 'io.github.gibbonsr4.ai-selects.aiSelectsCategory',      label = 'Category'         },
        { 'io.github.gibbonsr4.ai-selects.aiSelectsEyeQuality',   label = 'Eye Quality'      },
        { 'io.github.gibbonsr4.ai-selects.aiSelectsNarrativeRole', label = 'Narrative Role'   },
        { 'io.github.gibbonsr4.ai-selects.aiSelectsReject',        label = 'Reject'           },
        { 'io.github.gibbonsr4.ai-selects.aiSelectsScoreDate',     label = 'Score Date'       },

        'com.adobe.separator',

        -- Story mode fields (populated during narrative selection)
        { 'io.github.gibbonsr4.ai-selects.aiSelectsSequence',     label = 'Sequence'          },
        { 'io.github.gibbonsr4.ai-selects.aiSelectsStoryNote',    label = 'Story Note'        },
    },
}
