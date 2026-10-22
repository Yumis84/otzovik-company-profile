// Compatibility entrypoint: all rendering now belongs to the common cabinet shell.
import {renderNavigation} from './account-profile-shell.js';
import {profileAdapter} from './account-profile-adapters.js';
export {isUUID} from './account-profile-core.js';
export {text,optimizeImage} from './account-profile-shell.js';
export function navigation(node,id,active='profile'){renderNavigation(node,profileAdapter('specialist'),id,active);}
