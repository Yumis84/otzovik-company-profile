// Emits candidates only. Never connects to any database. Base draft migration is prerequisite.
import fs from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
export async function editorMigrationSQL(){
 const files=['20261017_specialist_editor_CANDIDATE.sql','20261017_specialist_media_CANDIDATE.sql','20261017_specialist_lifecycle_CANDIDATE.sql','20261027_specialist_storage_integrity_CANDIDATE.sql'];
 const parts=await Promise.all(files.map(async name=>(await fs.readFile(new URL('../sql/'+name,import.meta.url),'utf8')).replace(/^BEGIN;\s*$/gm,'').replace(/^COMMIT;\s*$/gm,'')));
 return 'BEGIN;\n'+parts.join('\n')+'\nCOMMIT;\n';
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href)process.stdout.write(await editorMigrationSQL());
