<?php

/**
 * @file
 * Enables modules and site configuration for a Pink site installation.
 */

use Symfony\Component\Yaml\Yaml;
use Drupal\Core\Form\FormStateInterface;
use Drupal\pink\Config\ConfigBit;
use Drupal\pink\Form\PinkExtraFeaturesForm;

/**
 * Implements hook_form_FORM_ID_alter() for install_configure_form().
 *
 * Allows the profile to alter the site configuration form.
 */
function pink_form_install_configure_form_alter(&$form, FormStateInterface $form_state) {

  // Add a placeholder as example that one can choose an arbitrary site name.
  $form['site_information']['site_name']['#attributes']['placeholder'] = t('Drupal Pink');

  // Default site email.
  $form['site_information']['site_mail']['#default_value'] = 'drupal_updates@insign.fr';

  // Regional settings.
  $form['regional_settings']['site_default_country']['#default_value'] = 'FR';
  $form['regional_settings']['date_default_timezone']['#default_value'] = 'Europe/Paris';

  // Notifications.
  $form['update_notifications']['update_status_module']['#default_value'] = [];

  // Default user 1 username should be 'admin'.
  $form['admin_account']['account']['name']['#default_value'] = 'admin';
  $form['admin_account']['account']['name']['#attributes']['disabled'] = TRUE;
  $form['admin_account']['account']['mail']['#default_value'] = 'drupal_updates@insign.fr';
  $form['admin_account']['account']['mail']['#description'] = t('In most case, and for <a target="_blank" href="@link">Insign Pink</a> specific use, we recommend this to always be <em>drupal_updates@insign.fr</em>.', ['@link' => 'https://www.insign.fr']);

}

/**
 * Implements hook_install_tasks().
 */
function pink_install_tasks(&$install_state) {

  return [
    'pink_extra_features' => [
      'display_name' => t('Select Features'),
      'display' => TRUE,
      'type' => 'form',
      'function' => PinkExtraFeaturesForm::class,
    ],
    'pink_assemble_extra_components' => [
      'display_name' => t('Install Extra Components'),
      'display' => TRUE,
      'type' => 'batch',
    ],
  ];
}

/**
 * Implements hook_install_tasks_alter().
 */
function pink_install_tasks_alter(array &$tasks, array $install_state) {
  $tasks['install_finished']['function'] = 'pink_after_install_finished';
}

/**
 * Batch job to assemble Pink extra components.
 *
 * @param array $install_state
 *   The current install state.
 *
 * @return array
 *   The batch job definition.
 */
function pink_assemble_extra_components(array &$install_state) {

  // Default Pink components, which must be installed.
  $default_components = ConfigBit::getList('configbit/default.components.pink.bit.yml', 'install_default_components', TRUE, 'dependencies', 'profile', 'pink');

  $batch = [];

  // Install default components first.
  foreach ($default_components as $default_component) {
    $batch['operations'][] = ['pink_assemble_extra_component_then_install', (array) $default_component];
  }

  // Install selected extra features.
  $selected_extra_features = [];

  if (isset($install_state['pink']['extra_features_values'])) {
    $selected_extra_features = $install_state['pink']['extra_features_values'];
  }

  // Get the list of extra features config bits.
  $extraFeatures = ConfigBit::getList('configbit/extra.features.pink.bit.yml', 'show_extra_features', TRUE, 'dependencies', 'profile', 'pink');

  // If we do have selected extra features.
  if (count($selected_extra_features) && count($extraFeatures)) {
    // Have batch processes for each selected extra features.
    foreach ($selected_extra_features as $extra_feature_key => $extra_feature_checked) {
      if ($extra_feature_checked) {

        // If the extra feature was a module and not enabled, then enable it.
        if (!\Drupal::moduleHandler()->moduleExists($extra_feature_key)) {
          // Add the checked extra feature to the batch process to be enabled.
          $batch['operations'][] = ['pink_assemble_extra_component_then_install', (array) $extra_feature_key];
        }
      }
    }

  }

  return $batch;
}

/**
 * Batch function to assemble and install needed extra components.
 *
 * @param string|array $extra_component
 *   Name of the extra component.
 */
function pink_assemble_extra_component_then_install($extra_component) {
  \Drupal::service('module_installer')->install((array) $extra_component, TRUE);
}

/**
 * Pink after install finished.
 *
 * Lanuch auto Pink Tour auto launch after install.
 *
 * @param array $install_state
 *   The current install state.
 *
 * @return array
 *   A renderable array with a redirect header.
 */
function pink_after_install_finished(array &$install_state) {

  // Entity updates to clear up any mismatched entity and/or field definitions
  // And Fix changes were detected in the entity type and field definitions.
  /*\Drupal::classResolver()
    ->getInstanceFromDefinition(PinkEntityDefinitionUpdateManager::class)
    ->applyUpdates();*/

  // Full flash and clear cash and rebuilding newly created routes.
  // After install of extra modules by install: in the .info.yml files.
  // In Pink profile and all Pink components.
  // ---------------------------------------------------------------------------
  // * Necessary inlitilization for the entire system.
  // * Account for changed config by the end install.
  // * Flush all persistent caches.
  // * Flush asset file caches.
  // * Wipe the Twig PHP Storage cache.
  // * Rebuild module and theme data.
  // * Clear all plugin caches.
  // * Rebuild the menu router based on all rebuilt data.
  // drupal_flush_all_caches();

  global $base_url;

  // After install direction.
  $after_install_direction = $base_url . '/?welcome';

  install_finished($install_state);
  $output = [];

  // Clear all messages.
  drupal_get_messages();

  $output = [
    '#title' => t('Pink'),
    'info' => [
      '#markup' => t('<p>Congratulations, you have installed Pink!</p><p>If you are not redirected to the front page in 5 seconds, Please <a href="@url">click here</a> to proceed to your installed site.</p>', [
        '@url' => $after_install_direction,
      ]),
    ],
    '#attached' => [
      'http_header' => [
        ['Cache-Control', 'no-cache'],
      ],
    ],
  ];

  $meta_redirect = [
    '#tag' => 'meta',
    '#attributes' => [
      'http-equiv' => 'refresh',
      'content' => '0;url=' . $after_install_direction,
    ],
  ];
  $output['#attached']['html_head'][] = [$meta_redirect, 'meta_redirect'];

  return $output;
}
