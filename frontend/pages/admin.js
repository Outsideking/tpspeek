import {useEffect, useState} from 'react'
export default function Admin(){
  const [users,setUsers] = useState([])
  useEffect(()=>{ fetch('/admin/users').then(r=>r.json()).then(setUsers) },[])
  return (
    <div style={{padding:40}}>
      <h1>Admin</h1>
      <table border={1}><thead><tr><th>ID</th><th>Name</th><th>Email</th></tr></thead>
      <tbody>{users.map(u=> <tr key={u.id}><td>{u.id}</td><td>{u.name}</td><td>{u.email}</td></tr>)}</tbody></table>
    </div>
  )
}
