// Emit the reviewed candidates as ONE transaction. Never connects to a database.
import fs from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
export async function migrationSQL(){
 const names=['20261017_specialist_drafts_independent_CANDIDATE.sql','20261017_specialist_draft_edit_CANDIDATE.sql'];
 const parts=[];
 for(const name of names){
  const sql=await fs.readFile(new URL('../sql/'+name,import.meta.url),'utf8');
  parts.push(sql.replace(/^BEGIN;\s*$/gm,'').replace(/^COMMIT;\s*$/gm,''));
 }
 return 'BEGIN;\n'+parts.join('\n')+'\nCOMMIT;\n';
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href)process.stdout.write(await migrationSQL());
