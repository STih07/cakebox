module PageFactory.ModelBuilder.View
  ( modelBuilderPanel
  , modelBuilderView
  ) where

-- UI for user/agent-defined entity model configuration.

import PageFactory.Engine (Html, tag, text)
import PageFactory.ModelBuilder.Store (ModelConfig (..))

modelBuilderView :: [ModelConfig] -> Html
modelBuilderView models =
  tag
    "main"
    [("class", "shell"), ("data-render-part", "model-builder")]
    ( tag "section" [("class", "profile model-hero")]
        ( tag "p" [("class", "eyebrow")] (text "Model Builder")
            <> tag "h1" [] (text "Модели")
            <> tag "p" [] (text "Фабрика сущностей: агент и экран создают модели с именем, цветом и коротким описанием. Визуал может быть разным, operation contract общий.")
        )
        <> modelBuilderPanel models
    )

modelBuilderPanel :: [ModelConfig] -> Html
modelBuilderPanel models =
  tag
    "section"
    [("class", "model-panel"), ("data-fragment-slot", "model-builder-panel")]
    ( newModelForm
        <> tag "section" [("class", "model-grid")] (foldMap modelCard models)
    )

newModelForm :: Html
newModelForm =
  tag
    "form"
    [ ("class", "model-form")
    , ("data-extension-action-form", "create_model")
    ]
    ( tag "input" [("name", "name"), ("placeholder", "Model name"), ("autocomplete", "off"), ("aria-label", "Model name")] mempty
        <> tag "input" [("name", "color"), ("placeholder", "#2f7d58"), ("autocomplete", "off"), ("aria-label", "Model color")] mempty
        <> tag "input" [("name", "description"), ("placeholder", "Short description"), ("autocomplete", "off"), ("aria-label", "Model description")] mempty
        <> tag "button" [("type", "submit")] (text "Create")
    )

modelCard :: ModelConfig -> Html
modelCard model =
  tag
    "article"
    [("class", "model-card"), ("style", "--model-color: " <> modelColor model)]
    ( tag "span" [("class", "model-swatch"), ("aria-hidden", "true")] mempty
        <> tag "form"
          [ ("class", "model-config-form")
          , ("data-extension-action-form", "update_model")
          ]
          ( tag "input" [("type", "hidden"), ("name", "slug"), ("value", modelSlug model)] mempty
              <> tag "input" [("name", "name"), ("value", modelName model), ("autocomplete", "off"), ("aria-label", "Model name")] mempty
              <> tag "input" [("name", "color"), ("value", modelColor model), ("autocomplete", "off"), ("aria-label", "Model color")] mempty
              <> tag "textarea" [("name", "description"), ("rows", "3"), ("aria-label", "Model description")] (text (modelDescription model))
              <> tag "div" [("class", "model-actions")]
                ( tag "button" [("type", "submit")] (text "Save")
                    <> tag "button" [("type", "button"), ("data-extension-action", "refresh_models")] (text "Refresh")
                    <> tag "button" [("type", "button"), ("data-extension-action", "delete_model"), ("data-slug", modelSlug model)] (text "Delete")
                )
          )
    )
